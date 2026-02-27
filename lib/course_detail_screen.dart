import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:sam_jas_academy/my_courses_screen.dart';
import 'package:sam_jas_academy/cart_screen.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class CourseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> courseData;
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseData, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> with RouteAware {
  final Color goldAccent = const Color(0xFFD4A373);
  final Color darkCard = const Color(0xFF1A1A1A);
  
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  
  bool isEnrolled = false;
  bool isInCart = false;
  bool isLoading = false;

  StreamSubscription? _enrollmentSubscription;
  StreamSubscription? _cartSubscription;

  @override
  void initState() {
    super.initState();
    _initStatusListeners();
    _initPlayer(widget.courseData['promoVideoUrl']);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void didPushNext() {
    _pauseVideo();
    super.didPushNext();
  }

  void _navigateTo(Widget screen) {
    // Dismiss the snackbar instantly when moving forward
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _pauseVideo();
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _pauseVideo() {
    if (_videoPlayerController != null && _videoPlayerController!.value.isPlaying) {
      _videoPlayerController!.pause();
    }
  }

  void _initStatusListeners() {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    _enrollmentSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists && mounted) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        List enrolled = data['enrolledCourses'] ?? [];
        bool inList = enrolled.contains(widget.courseId);

        Map<String, dynamic> subs = data['subscriptions'] ?? {};
        Map<String, dynamic>? courseSub = subs[widget.courseId];

        bool hasValidAccess = false;
        if (inList && courseSub != null) {
          bool active = courseSub['isActive'] ?? false;
          Timestamp? expiry = courseSub['expiryDate'];
          if (active && expiry != null) {
            hasValidAccess = DateTime.now().isBefore(expiry.toDate());
          }
        }

        setState(() {
          isEnrolled = hasValidAccess;
        });
      }
    });

    _cartSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cart')
        .doc(widget.courseId)
        .snapshots()
        .listen((cartDoc) {
      if (mounted) {
        setState(() {
          isInCart = cartDoc.exists;
        });
      }
    });
  }

  void _addToCart() async {
    setState(() => isLoading = true);
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'hasActiveCart': true,
        'lastActivity': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cart')
          .doc(widget.courseId)
          .set({
        'courseId': widget.courseId,
        'title': widget.courseData['title'],
        'price': widget.courseData['price'],
        'thumbnailUrl': widget.courseData['thumbnailUrl'] ?? '',
        'addedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Added to Cart!"),
            backgroundColor: Colors.green,
            duration: Duration(days: 1), // Keeps it visible until manual dismissal or navigation
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Cart Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _initPlayer(String url) async {
    if (url.isEmpty) return;
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await _videoPlayerController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        aspectRatio: 16 / 9,
        materialProgressColors: ChewieProgressColors(playedColor: goldAccent),
      );
    } catch (e) {
      debugPrint("Video Init Error: $e");
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _enrollmentSubscription?.cancel();
    _cartSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Clears snackbar when going back via gesture or hardware button
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('cart')
                  .snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Badge(
                  label: Text(count.toString(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  backgroundColor: goldAccent,
                  isLabelVisible: count > 0,
                  child: IconButton(
                    icon: Icon(Icons.shopping_cart_outlined, color: goldAccent),
                    onPressed: () => _navigateTo(const CartScreen()),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
          ],
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  // Clears snackbar when using the UI back button
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: _chewieController != null
                      ? Chewie(controller: _chewieController!)
                      : const Center(child: CircularProgressIndicator(color: Color(0xFFD4A373))),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.courseData['title'],
                        style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 10),
                    if (!isEnrolled)
                      Text("₹${widget.courseData['price'] ?? '0'}",
                          style: GoogleFonts.montserrat(fontSize: 20, color: goldAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 25),
                    Text("ABOUT THIS COURSE", style: GoogleFonts.montserrat(fontSize: 12, color: goldAccent, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    Text(widget.courseData['description'],
                        style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 14)),
                    const SizedBox(height: 30),
                    Text("COURSE CURRICULUM", style: GoogleFonts.montserrat(fontSize: 12, color: goldAccent, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 15),
                    _buildSpaciousCurriculum(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomAction(),
      ),
    );
  }

  Widget _buildSpaciousCurriculum() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('lessons')
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var lessons = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lessons.length,
          itemBuilder: (context, index) {
            var lesson = lessons[index].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 28, width: 28,
                    decoration: BoxDecoration(color: goldAccent.withOpacity(0.1), shape: BoxShape.circle),
                    child: Center(
                      child: Text("${lesson['order'] ?? index + 1}", style: TextStyle(color: goldAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lesson['title'] ?? "Untitled Lesson", maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.lock_outline, color: goldAccent.withOpacity(0.5), size: 12),
                            const SizedBox(width: 4),
                            Text("LOCKED CONTENT", style: TextStyle(color: goldAccent.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(lesson['duration'] ?? "0:00", style: GoogleFonts.montserrat(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomAction() {
  // Logic check: Priority 1 = Enrolled, Priority 2 = In Cart, Priority 3 = Default
  Color getButtonColor() {
    if (isEnrolled) return Colors.green.shade800; // Purchased
    if (isInCart) return Colors.green;           // In Cart (Vibrant Green)
    return goldAccent;                            // Not in cart
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    decoration: BoxDecoration(
      color: const Color(0xFF161616),
      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
    ),
    child: SafeArea(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: getButtonColor(), // Applies the logic above
          minimumSize: const Size(double.infinity, 55),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          if (isEnrolled) {
            _navigateTo(MyCoursesScreen());
          } else if (isInCart) {
            _navigateTo(const CartScreen());
          } else {
            _addToCart();
          }
        },
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.black)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Show cart icon only when in cart and not yet enrolled
                  if (isInCart && !isEnrolled) ...[
                    const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    isEnrolled ? "GO TO MY PANEL" : (isInCart ? "VIEW IN CART" : "ADD TO CART"),
                    style: GoogleFonts.montserrat(
                      color: (isEnrolled || isInCart) ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}
}