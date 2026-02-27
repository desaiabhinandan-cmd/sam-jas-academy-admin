class CourseCategory {
  final String id;
  final String name;
  final String imageUrl;

  CourseCategory({required this.id, required this.name, required this.imageUrl});

  // Convert Firestore data to our Model
  factory CourseCategory.fromMap(Map<String, dynamic> data, String id) {
    return CourseCategory(
      id: id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}