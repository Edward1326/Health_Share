import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/crypto_utils.dart';

class FileShareToOrgService {
  static final _supabase = Supabase.instance.client;

  /// Share files with selected doctors/organizations
  static Future<void> shareFilesToDoctors(
    List<String> fileIds,
    List<String> doctorIds,
    String userId,
  ) async {
    try {
      print('=== DOCTOR SHARING DEBUG ===');
      print('User ID: $userId');
      print('Files to share: ${fileIds.length}');
      print('File IDs: $fileIds');
      print('Doctors selected: ${doctorIds.length}');
      print('Doctor IDs: $doctorIds');

      // STEP 1: Validate user exists and has RSA key
      print('\n--- Step 1: Fetching user RSA key ---');
      final userData =
          await _supabase
              .from('User')
              .select('rsa_private_key, email')
              .eq('id', userId)
              .maybeSingle();

      if (userData == null) {
        throw Exception('User not found with ID: $userId');
      }

      final userRsaPrivateKeyPem = userData['rsa_private_key'] as String?;
      if (userRsaPrivateKeyPem == null || userRsaPrivateKeyPem.isEmpty) {
        throw Exception(
          'User RSA private key is missing for user: ${userData['email']}',
        );
      }

      print('✓ User found: ${userData['email']}');
      print('✓ RSA private key length: ${userRsaPrivateKeyPem.length}');

      final userRsaPrivateKey = MyCryptoUtils.rsaPrivateKeyFromPem(
        userRsaPrivateKeyPem,
      );

      // STEP 2: Validate all files exist and user has access
      print('\n--- Step 2: Validating file access ---');
      for (final fileId in fileIds) {
        final fileCheck =
            await _supabase
                .from('File_Keys')
                .select('file_id')
                .eq('file_id', fileId)
                .eq('recipient_type', 'user')
                .eq('recipient_id', userId)
                .maybeSingle();

        if (fileCheck == null) {
          throw Exception('User does not have access to file: $fileId');
        }
        print('✓ File access confirmed: $fileId');
      }

      // STEP 3: Validate all doctors exist
      print('\n--- Step 3: Validating doctors ---');
      for (final doctorId in doctorIds) {
        final doctorCheck =
            await _supabase
                .from('Organization_User')
                .select('id, position, User!user_id(email, rsa_public_key)')
                .eq('id', doctorId)
                .eq('position', 'Doctor')
                .maybeSingle();

        if (doctorCheck == null) {
          throw Exception('Doctor not found with ID: $doctorId');
        }

        final doctorUser = doctorCheck['User'];
        if (doctorUser == null) {
          throw Exception('Doctor user data not found for ID: $doctorId');
        }

        final publicKey = doctorUser['rsa_public_key'] as String?;
        if (publicKey == null || publicKey.isEmpty) {
          throw Exception(
            'Doctor RSA public key missing for: ${doctorUser['email']}',
          );
        }

        print('✓ Doctor validated: ${doctorUser['email']} ($doctorId)');
      }

      // STEP 4: Share with each doctor
      print('\n--- Step 4: Processing shares ---');
      for (final doctorId in doctorIds) {
        try {
          await _shareFilesToSingleDoctor(
            fileIds,
            doctorId,
            userRsaPrivateKey,
            userId,
          );
          print('✓ Successfully shared with doctor: $doctorId');
        } catch (e) {
          print('✗ Failed to share with doctor $doctorId: $e');
          rethrow; // Re-throw to stop the process
        }
      }

      print('\n✓ Successfully shared files to all doctors');
    } catch (e, stackTrace) {
      print('❌ CRITICAL ERROR in shareFilesToDoctors: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Share files with a single doctor
  static Future<void> _shareFilesToSingleDoctor(
    List<String> fileIds,
    String doctorId,
    dynamic userRsaPrivateKey,
    String userId,
  ) async {
    try {
      // Get doctor details
      final doctorData = await _fetchDoctorDetails(doctorId);
      if (doctorData == null) {
        print('Doctor $doctorId not found');
        return;
      }

      final doctorUser = doctorData['user'];
      final doctorName = _formatFullName(doctorUser);
      final doctorRsaPublicKeyPem = doctorUser['rsa_public_key'] as String;
      final doctorRsaPublicKey = MyCryptoUtils.rsaPublicKeyFromPem(
        doctorRsaPublicKeyPem,
      );

      print('\n--- Processing doctor: $doctorName ($doctorId) ---');

      for (final fileId in fileIds) {
        await _shareFileToDoctor(
          fileId,
          doctorId,
          doctorName,
          doctorRsaPublicKey,
          userRsaPrivateKey,
          userId,
        );
      }
    } catch (e) {
      print('Error processing doctor $doctorId: $e');
      rethrow;
    }
  }

  /// Share a single file with a doctor
  static Future<void> _shareFileToDoctor(
    String fileId,
    String doctorId,
    String doctorName,
    dynamic doctorRsaPublicKey,
    dynamic userRsaPrivateKey,
    String userId,
  ) async {
    try {
      print('\n    Processing file $fileId for doctor $doctorName');

      // Get doctor details to extract the actual user_id
      final doctorData = await _fetchDoctorDetails(doctorId);
      if (doctorData == null) {
        throw Exception('Doctor details not found for $doctorId');
      }

      final doctorUserId = doctorData['user']['id'] as String;
      print('    📋 Doctor user_id: $doctorUserId');

      // Check if already shared (using doctor's User.id)
      final existingShare =
          await _supabase
              .from('File_Shares')
              .select('id')
              .eq('file_id', fileId)
              .eq('shared_with_doctor', doctorUserId) // Use User.id
              .isFilter('revoked_at', null)
              .maybeSingle();

      if (existingShare != null) {
        print(
          '    ⚠️  File $fileId already shared with doctor $doctorName, skipping...',
        );
        return;
      }

      // Get user's encrypted AES key with detailed error handling
      print('    📋 Fetching user\'s encrypted key...');
      final userFileKeys = await _supabase
          .from('File_Keys')
          .select('aes_key_encrypted, nonce_hex')
          .eq('file_id', fileId)
          .eq('recipient_type', 'user')
          .eq('recipient_id', userId);

      if (userFileKeys.isEmpty) {
        throw Exception('No File_Keys found for file $fileId and user $userId');
      }

      if (userFileKeys.length > 1) {
        print('    ⚠️  Multiple File_Keys found, using first one');
      }

      final userFileKey = userFileKeys.first;
      final encryptedKeyPackage = userFileKey['aes_key_encrypted'] as String?;
      final nonceHex = userFileKey['nonce_hex'] as String?;

      if (encryptedKeyPackage == null || encryptedKeyPackage.isEmpty) {
        throw Exception('Encrypted key package is null/empty for file $fileId');
      }

      print(
        '    ✓ Retrieved encrypted key package (${encryptedKeyPackage.length} chars)',
      );

      // Validate encrypted package size
      final encryptedBytes = base64Decode(encryptedKeyPackage);
      if (encryptedBytes.length > 512) {
        // Increased limit for safety
        throw Exception(
          'Encrypted key package too large: ${encryptedBytes.length} bytes',
        );
      }

      // Decrypt and re-encrypt for doctor
      print('    🔓 Decrypting key package...');
      final decryptedKeyJson = MyCryptoUtils.rsaDecrypt(
        encryptedKeyPackage,
        userRsaPrivateKey,
      );

      print('    🔒 Re-encrypting for doctor...');
      final doctorEncryptedKeyPackage = MyCryptoUtils.rsaEncrypt(
        decryptedKeyJson,
        doctorRsaPublicKey,
      );

      // Create share record using doctor's User.id for consistency
      print('    📝 Creating File_Shares record...');
      final shareInsertData = {
        'file_id': fileId,
        'shared_with_doctor':
            doctorUserId, // Use User.id instead of Organization_User.id
        'shared_by_user_id': userId,
        'shared_at': DateTime.now().toIso8601String(),
      };

      final shareResult =
          await _supabase
              .from('File_Shares')
              .insert(shareInsertData)
              .select()
              .single();

      print('    ✓ File_Shares created: ${shareResult['id']}');

      // Create doctor key record using User.id
      print('    🔑 Creating File_Keys record for doctor...');
      final keyInsertData = {
        'file_id': fileId,
        'recipient_type': 'user',
        'recipient_id': doctorUserId, // Use User.id
        'aes_key_encrypted': doctorEncryptedKeyPackage,
        if (nonceHex != null && nonceHex.isNotEmpty) 'nonce_hex': nonceHex,
      };

      final keyResult =
          await _supabase
              .from('File_Keys')
              .insert(keyInsertData)
              .select()
              .single();

      print('    ✓ File_Keys created: ${keyResult['id']}');
      print('    🎉 File $fileId successfully shared with doctor $doctorName');
    } catch (e, stackTrace) {
      print('    ❌ Error sharing file $fileId with doctor $doctorName: $e');
      print('    Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Fetch assigned doctors for the current user
  static Future<List<Map<String, dynamic>>> fetchAssignedDoctors(
    String userId,
  ) async {
    try {
      print('Fetching assigned doctors for user: $userId');

      // First, get the patient record for this user
      final patientResponse =
          await _supabase
              .from('Patient')
              .select('id')
              .eq('user_id', userId)
              .maybeSingle();

      if (patientResponse == null) {
        print('No patient record found for user: $userId');
        return [];
      }

      final patientId = patientResponse['id'] as String;
      print('Found patient ID: $patientId');

      // Query Doctor_User_Assignment and join with Organization_User
      final doctorsResponse = await _supabase
          .from('Doctor_User_Assignment')
          .select('''
          id,
          doctor_id,
          patient_id,
          assigned_at,
          status,
          Organization_User!doctor_id(
            id,
            position,
            department,
            organization_id,
            user_id,
            User!user_id(
              id,
              email,
              rsa_public_key,
              Person!person_id(
                first_name,
                middle_name,
                last_name
              )
            ),
            Organization!organization_id(
              id,
              name,
              description,
              location,
              email,
              contact_number
            )
          )
        ''')
          .eq('patient_id', patientId)
          .eq('status', 'active');

      print('Raw response from Doctor_User_Assignment: $doctorsResponse');

      // Filter out any null Organization_User records and ensure they are doctors
      final validDoctors =
          doctorsResponse.where((assignment) {
            final orgUser = assignment['Organization_User'];
            return orgUser != null &&
                orgUser['position'] == 'Doctor' &&
                orgUser['User'] != null;
          }).toList();

      print('Valid doctor assignments found: ${validDoctors.length}');

      // Transform the response to match expected format
      final transformedDoctors =
          validDoctors.map<Map<String, dynamic>>((assignment) {
            final orgUser = assignment['Organization_User'];
            final doctorUser = orgUser['User'];
            final organization = orgUser['Organization'];

            return {
              'assignment_id': assignment['id'],
              'doctor_id': assignment['doctor_id'],
              'patient_id': assignment['patient_id'],
              'assigned_at': assignment['assigned_at'],
              'status': assignment['status'],
              'organization_id': orgUser['organization_id'],
              'organization_name':
                  organization['name'] ?? 'Unknown Organization',
              'position': orgUser['position'],
              'department': orgUser['department'],
              'organization_email': organization['email'],
              'organization_contact': organization['contact_number'],
              'organization_location': organization['location'],
              'user':
                  doctorUser, // Contains doctor's user info and Person details
            };
          }).toList();

      print('Fetched ${transformedDoctors.length} assigned doctors');

      // Debug: Print each doctor's name for verification
      for (final doctor in transformedDoctors) {
        final doctorName = _formatFullName(doctor['user']);
        print('Doctor found: $doctorName (${doctor['doctor_id']})');
      }

      return transformedDoctors;
    } catch (e, stackTrace) {
      print('Error fetching assigned doctors: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Fetch detailed doctor information
  static Future<Map<String, dynamic>?> _fetchDoctorDetails(
    String doctorId,
  ) async {
    try {
      final doctorResponse =
          await _supabase
              .from('Organization_User')
              .select('''
            id,
            position,
            department,
            organization_id,
            user_id,
            User!user_id(
              id,
              email,
              rsa_public_key,
              Person!person_id(
                first_name,
                middle_name,
                last_name
              )
            ),
            Organization!organization_id(
              id,
              name,
              description,
              location,
              email,
              contact_number
            )
          ''')
              .eq('id', doctorId)
              .maybeSingle();

      if (doctorResponse == null) return null;

      return {
        'doctor_id': doctorId,
        'organization_id': doctorResponse['organization_id'],
        'organization_name': doctorResponse['Organization']['name'],
        'position': doctorResponse['position'],
        'department': doctorResponse['department'],
        'user': doctorResponse['User'],
      };
    } catch (e) {
      print('Error fetching doctor details for $doctorId: $e');
      return null;
    }
  }

  /// Helper method to format full name
  static String _formatFullName(Map<String, dynamic> user) {
    final person = user['Person'];
    if (person == null) {
      return user['email'] ?? 'Unknown User';
    }

    final firstName = person['first_name']?.toString().trim() ?? '';
    final middleName = person['middle_name']?.toString().trim() ?? '';
    final lastName = person['last_name']?.toString().trim() ?? '';

    List<String> nameParts = [];

    if (firstName.isNotEmpty) nameParts.add(firstName);
    if (middleName.isNotEmpty) nameParts.add(middleName);
    if (lastName.isNotEmpty) nameParts.add(lastName);

    if (nameParts.isEmpty) {
      return user['email'] ?? 'Unknown User';
    }

    return nameParts.join(' ');
  }

  /// Check if files are already shared with specific doctors
  /// Updated to use doctor User.id instead of Organization_User.id
  static Future<Map<String, Set<String>>> getExistingDoctorShares(
    List<String> fileIds,
    List<String> doctorIds,
  ) async {
    try {
      // First, get the User.id for each doctorId (Organization_User.id)
      final doctorUserIds = <String, String>{};
      for (final doctorId in doctorIds) {
        final doctorData = await _fetchDoctorDetails(doctorId);
        if (doctorData != null) {
          final doctorUserId = doctorData['user']['id'] as String;
          doctorUserIds[doctorId] = doctorUserId;
        }
      }

      final userIds = doctorUserIds.values.toList();

      final existingShares = await _supabase
          .from('File_Shares')
          .select('file_id, shared_with_doctor')
          .inFilter('file_id', fileIds)
          .inFilter('shared_with_doctor', userIds); // Use User.id

      final Map<String, Set<String>> result = {};

      for (final share in existingShares) {
        final fileId = share['file_id'] as String;
        final doctorUserId = share['shared_with_doctor'] as String;

        // Find the corresponding Organization_User.id for this User.id
        final doctorId =
            doctorUserIds.entries
                .firstWhere(
                  (entry) => entry.value == doctorUserId,
                  orElse: () => const MapEntry('', ''),
                )
                .key;

        if (doctorId.isNotEmpty) {
          if (!result.containsKey(fileId)) {
            result[fileId] = <String>{};
          }
          result[fileId]!.add(doctorId);
        }
      }

      return result;
    } catch (e) {
      print('Error checking existing doctor shares: $e');
      return {};
    }
  }

  /// Validate doctor assignment before sharing
  static Future<bool> validateDoctorAssignment(
    String userId,
    String doctorId,
  ) async {
    try {
      // First get the patient_id from the userId
      final patientResponse =
          await _supabase
              .from('Patient')
              .select('id')
              .eq('user_id', userId)
              .maybeSingle();

      if (patientResponse == null) {
        print('No patient record found for user: $userId');
        return false;
      }

      final patientId = patientResponse['id'] as String;

      // Check if there's an active assignment between this patient and doctor
      final assignmentCheck =
          await _supabase
              .from('Doctor_User_Assignment')
              .select('id, status')
              .eq('patient_id', patientId)
              .eq('doctor_id', doctorId)
              .eq('status', 'active')
              .maybeSingle();

      final isValid = assignmentCheck != null;
      print(
        'Doctor assignment validation - Patient: $patientId, Doctor: $doctorId, Valid: $isValid',
      );

      return isValid;
    } catch (e) {
      print('Error validating doctor assignment: $e');
      return false;
    }
  }
}
