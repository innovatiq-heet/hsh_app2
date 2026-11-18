// Calls the live AVD VVN student API; results change with real data. CI skips
// it (`flutter test --exclude-tags live`).
@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/enums/admission_status.dart';
import 'package:hsh_app2/core/models/student_profile/student_profile_model.dart';
import 'package:hsh_app2/core/network/api_client.dart';
import 'package:hsh_app2/core/network/repository/student_profile/student_profile_repository.dart';

import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.put(SessionStore());
    Get.put(ApiClient.create());
  });

  tearDown(() {
    Get.reset();
  });

  test('StudentProfileModel correctly parses external AVD student JSON', () {
    final json = {
      "firstName": "Harshil",
      "middleName": "Vijaybhai ",
      "lastName": "Patel ",
      "phone": "9725714912",
      "fatherPhone": "9723414912",
      "motherPhone": "9586472972",
      "whatsAppNumber": "9725714912",
      "email": "harshil2937patel@gmail.com",
      "dob": "2007-03-29",
      "groupName": "Pavitra",
      "room": "913",
      "bankCode": "0987",
      "aadhar": "810200748347",
      "status": "renewed-admission"
    };

    final profile = StudentProfileModel.fromJson(json);

    expect(profile.firstName, 'Harshil');
    expect(profile.middleName, 'Vijaybhai');
    expect(profile.lastName, 'Patel');
    expect(profile.fullName, 'Harshil Vijaybhai Patel');
    expect(profile.phone, '9725714912');
    expect(profile.whatsappNumber, '9725714912');
    expect(profile.email, 'harshil2937patel@gmail.com');
    expect(profile.dob, '2007-03-29');
    expect(profile.room, '913');
    expect(profile.groupName, 'Pavitra');
    expect(profile.bankCode, '0987');
    expect(profile.aadhar, '810200748347');
    expect(profile.fatherPhone, '9723414912');
    expect(profile.motherPhone, '9586472972');
    expect(profile.status, AdmissionStatus.active);
  });

  test('StudentProfileModel correctly parses expanded family and address fields', () {
    final json = {
      "firstName": "Smit",
      "middleName": "Hasmukhbhai",
      "lastName": "Padaliya",
      "phone": "9409726301",
      "fatherFirstName": "Hasmukhbhai",
      "fatherMiddleName": "K",
      "fatherLastName": "Padaliya",
      "fatherPhone": "9825123456",
      "fatherBusiness": "Diamond Business",
      "fatherDob": "1974-05-15",
      "motherFirstName": "Hansaben",
      "motherMiddleName": "H",
      "motherLastName": "Padaliya",
      "motherPhone": "9825654321",
      "motherBusiness": "Home Maker",
      "motherDob": "1977-08-20",
      "anniversary": "974658600000",
      "address": "12 Shanti Nagar",
      "city": "Surat",
      "district": "Surat",
      "state": "Gujarat",
      "pinCode": "395006",
      "whatsAppNumber": "9409726301",
      "email": "shpadalia18@gmail.com",
      "dob": "1999-08-27",
      "room": "308",
      "groupName": "Pavitra",
      "bankCode": "0028",
      "aadhar": "123456789012",
      "status": "active"
    };

    final profile = StudentProfileModel.fromJson(json);

    expect(profile.fatherFullName, 'Hasmukhbhai K Padaliya');
    expect(profile.fatherBusiness, 'Diamond Business');
    expect(profile.fatherProfession, 'Diamond Business');
    expect(profile.fatherDob, '1974-05-15');
    expect(profile.motherFullName, 'Hansaben H Padaliya');
    expect(profile.motherBusiness, 'Home Maker');
    expect(profile.motherDob, '1977-08-20');
    expect(profile.anniversaryFormatted, '2000-11-20');
    expect(profile.hometown, 'Surat, Gujarat');
  });

  test('matchStudent correctly identifies target student by phone, aadhar, or bank code', () {
    final repo = StudentProfileRepository();
    final sampleList = [
      {
        "firstName": "Other",
        "lastName": "Student",
        "phone": "9999999999",
        "whatsAppNumber": "9999999999",
        "email": "other@example.com",
        "bankCode": "1234",
        "aadhar": "111122223333",
        "status": "active"
      },
      {
        "firstName": "Harshil",
        "middleName": "Vijaybhai ",
        "lastName": "Patel ",
        "phone": "9725714912",
        "fatherPhone": "9723414912",
        "motherPhone": "9586472972",
        "whatsAppNumber": "9725714912",
        "email": "harshil2937patel@gmail.com",
        "dob": "2007-03-29",
        "groupName": "Pavitra",
        "room": "913",
        "bankCode": "0987",
        "aadhar": "810200748347",
        "status": "renewed-admission"
      }
    ];

    // Match by phone
    final byPhone = repo.matchStudent(sampleList, phone: '9725714912');
    expect(byPhone, isNotNull);
    expect(byPhone!['firstName'], 'Harshil');

    // Match by aadhar
    final byAadhar = repo.matchStudent(sampleList, aadhar: '810200748347');
    expect(byAadhar, isNotNull);
    expect(byAadhar!['firstName'], 'Harshil');

    // Match by bank code
    final byCode = repo.matchStudent(sampleList, studentCode: '0987');
    expect(byCode, isNotNull);
    expect(byCode!['firstName'], 'Harshil');

    // Match by normalized bank code
    final byNormCode = repo.matchStudent(sampleList, studentCode: '987');
    expect(byNormCode, isNotNull);
    expect(byNormCode!['firstName'], 'Harshil');

    // Match by email
    final byEmail = repo.matchStudent(sampleList, email: 'harshil2937patel@gmail.com');
    expect(byEmail, isNotNull);
    expect(byEmail!['firstName'], 'Harshil');
  });

  test('fetchProfile successfully fetches live details from external AVD API for student 9725714912', () async {
    final repo = StudentProfileRepository();
    final profile = await repo.fetchProfile(phone: '9725714912');

    expect(profile.firstName, 'Harshil');
    expect(profile.phone, '9725714912');
    expect(profile.whatsappNumber, '9725714912');
    expect(profile.email, 'harshil2937patel@gmail.com');
    expect(profile.dob, '2007-03-29');
    expect(profile.room, '913');
    expect(profile.groupName, 'Pavitra');
    expect(profile.bankCode, '0987');
    expect(profile.aadhar, '810200748347');
    expect(profile.fatherPhone, '9723414912');
    expect(profile.motherPhone, '9586472972');
    expect(profile.status, AdmissionStatus.active);
  });
}
