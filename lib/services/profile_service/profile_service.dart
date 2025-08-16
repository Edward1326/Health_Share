import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current user's profile data
  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final response =
        await _supabase
            .from('Person')
            .select('*')
            .eq('auth_user_id', user.id)
            .single();

    return response;
  }

  /// Update user profile
  Future<void> updateProfile({
    required String personId,
    String? address,
    String? contactNumber,
    String? bloodType,
    String? sex,
    List<String>? allergies,
    List<String>? medicalConditions,
    List<String>? currentMedications,
    List<String>? disabilities,
  }) async {
    final updateData = <String, dynamic>{};

    if (address != null) updateData['address'] = address;
    if (contactNumber != null) updateData['contact_number'] = contactNumber;
    if (bloodType != null) updateData['blood_type'] = bloodType;
    if (sex != null) updateData['sex'] = sex;
    if (allergies != null) updateData['allergies'] = allergies;
    if (medicalConditions != null)
      updateData['medical_conditions'] = medicalConditions;
    if (currentMedications != null)
      updateData['current_medications'] = currentMedications;
    if (disabilities != null) updateData['disabilities'] = disabilities;

    await _supabase.from('Person').update(updateData).eq('id', personId);
  }

  /// Upload profile image
  // Future<String> uploadProfileImage(String personId, String imagePath) async {
  //   final fileName = 'profile_$personId.jpg';

  //   await _supabase.storage
  //       .from('profile-images')
  //       .upload(fileName, File(imagePath));

  //   final publicUrl = _supabase.storage
  //       .from('profile-images')
  //       .getPublicUrl(fileName);

  //   // Update the person record with the image URL
  //   await _supabase
  //       .from('Person')
  //       .update({'image': publicUrl})
  //       .eq('id', personId);

  //   return publicUrl;
  // }

  /// Delete profile image
  Future<void> deleteProfileImage(String personId, String imageUrl) async {
    // Extract filename from URL
    final uri = Uri.parse(imageUrl);
    final fileName = uri.pathSegments.last;

    // Delete from storage
    await _supabase.storage.from('profile-images').remove([fileName]);

    // Update person record
    await _supabase.from('Person').update({'image': null}).eq('id', personId);
  }

  /// Get blood type options
  static List<String> getBloodTypeOptions() {
    return ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
  }

  /// Get sex options
  static List<String> getSexOptions() {
    return ['Male', 'Female'];
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
    return phoneRegex.hasMatch(phone) && phone.length >= 10;
  }

  /// Format list for display
  static String formatListForDisplay(List<dynamic>? list) {
    if (list == null || list.isEmpty) return 'Not provided';
    return list.join(', ');
  }

  /// Parse comma-separated string to list
  static List<String> parseStringToList(String text) {
    if (text.trim().isEmpty) return [];
    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
