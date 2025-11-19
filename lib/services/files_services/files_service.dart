import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class FilesService {
  static final _supabase = Supabase.instance.client;

  /// Fetch all files uploaded by the logged-in user
  static Future<List<Map<String, dynamic>>> fetchUserFiles(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('Files')
          .select('*')
          .eq('owned_by', userId)
          .isFilter('deleted_at', null)
          .order('uploaded_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching user files: $e");
      return [];
    }
  }

  /// Get appropriate icon based on category
  static IconData getFileIcon(String category) {
    return getCategoryIcon(category);
  }

  /// Get color based on category
  static Color getFileColor(String category) {
    switch (category) {
      case 'medical_report':
        return const Color(0xFF4299E1); // Blue
      case 'lab_results':
        return const Color(0xFF48BB78); // Green
      case 'prescription':
        return const Color(0xFF9F7AEA); // Purple
      case 'x_ray':
        return const Color(0xFF667EEA); // Indigo
      case 'mri_scan':
        return const Color(0xFFED64A6); // Pink
      case 'ct_scan':
        return const Color(0xFF38A169); // Dark Green
      case 'ultrasound':
        return const Color(0xFFECC94B); // Yellow
      case 'blood_test':
        return const Color(0xFFE53E3E); // Red
      case 'discharge_summary':
        return const Color(0xFFED8936); // Orange
      case 'consultation_notes':
        return const Color(0xFF4299E1); // Blue
      default:
        return const Color(0xFF718096); // Gray
    }
  }

  /// Format date to DD/MM/YYYY
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Format date and time to DD/MM/YYYY HH:MM AM/PM
  static String formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;

    int hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$day/$month/$year $hour:$minute $period';
  }

  /// Get icon for file category
  static IconData getCategoryIcon(String categoryKey) {
    switch (categoryKey) {
      case 'medical_report':
        return Icons.description_rounded;
      case 'lab_results':
        return Icons.science_rounded;
      case 'prescription':
        return Icons.medication_rounded;
      case 'x_ray':
        return Icons.photo_camera_rounded;
      case 'mri_scan':
        return Icons.monitor_heart_rounded;
      case 'ct_scan':
        return Icons.camera_enhance_rounded;
      case 'ultrasound':
        return Icons.sensors_rounded;
      case 'blood_test':
        return Icons.water_drop_rounded;
      case 'discharge_summary':
        return Icons.article_rounded;
      case 'consultation_notes':
        return Icons.notes_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  /// File categories map
  static const Map<String, String> fileCategories = {
    'ALL': 'All Files',
    'medical_report': 'Medical Report',
    'lab_results': 'Lab Results',
    'prescription': 'Prescription',
    'x_ray': 'X-ray',
    'mri_scan': 'MRI Scan',
    'ct_scan': 'CT Scan',
    'ultrasound': 'Ultrasound',
    'blood_test': 'Blood Test',
    'discharge_summary': 'Discharge Summary',
    'consultation_notes': 'Consultation Notes',
  };

  /// Filter files by search query and category
  static List<Map<String, dynamic>> filterFiles(
    List<Map<String, dynamic>> files,
    String searchQuery,
    String selectedFilter,
  ) {
    List<Map<String, dynamic>> filtered = files;

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered =
          filtered.where((file) {
            final filename = (file['filename'] ?? '').toString().toLowerCase();
            return filename.contains(searchQuery.toLowerCase());
          }).toList();
    }

    // Apply category filter
    if (selectedFilter != 'ALL') {
      filtered =
          filtered.where((file) {
            return file['category'] == selectedFilter;
          }).toList();
    }

    return filtered;
  }

  /// Format full name from user/person data
  static String formatFullName(Map<String, dynamic> user) {
    final person = user['Person'];
    if (person == null) return user['email'] ?? 'Unknown User';

    final firstName = person['first_name']?.toString().trim() ?? '';
    final middleName = person['middle_name']?.toString().trim() ?? '';
    final lastName = person['last_name']?.toString().trim() ?? '';

    List<String> nameParts = [];
    if (firstName.isNotEmpty) nameParts.add(firstName);
    if (middleName.isNotEmpty) nameParts.add(middleName);
    if (lastName.isNotEmpty) nameParts.add(lastName);

    return nameParts.isEmpty
        ? (user['email'] ?? 'Unknown User')
        : nameParts.join(' ');
  }
}
