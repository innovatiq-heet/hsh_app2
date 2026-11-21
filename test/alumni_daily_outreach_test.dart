import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/models/alumni/alumni_models.dart';

void main() {
  group('Alumni Daily Outreach Models & Logic Tests', () {
    test('AlumniOutreachStudentModel parses correctly from JSON', () {
      final json = {
        'outreachId': 10,
        'studentId': 1234,
        'name': 'Bhavik V. Patel',
        'studentCode': 'HSH_1234',
        'phone': '9876543210',
        'whatsappNumber': '+91 98765 43210',
        'pastRoom': '402',
        'graduationYear': 2023,
        'currentCompany': 'Google',
        'currentDesignation': 'Software Engineer',
        'currentCity': 'Bengaluru',
        'groupName': 'Param',
        'status': 'pending',
      };

      final student = AlumniOutreachStudentModel.fromJson(json);

      expect(student.studentId, 1234);
      expect(student.name, 'Bhavik V. Patel');
      expect(student.initials, 'BP');
      expect(student.pastRoom, '402');
      expect(student.graduationYear, 2023);
      expect(student.batchLabel, 'Batch of 2023');
      expect(student.currentRoleLine, 'Software Engineer at Google');
      expect(student.isPending, true);
      expect(student.isMessaged, false);
      expect(student.targetWhatsAppPhone, '919876543210');
    });

    test('AlumniDailyOutreachDataModel calculates progress accurately', () {
      final studentsJson = [
        {'studentId': 1, 'name': 'Alum 1', 'status': 'messaged'},
        {'studentId': 2, 'name': 'Alum 2', 'status': 'messaged'},
        {'studentId': 3, 'name': 'Alum 3', 'status': 'pending'},
        {'studentId': 4, 'name': 'Alum 4', 'status': 'pending'},
        {'studentId': 5, 'name': 'Alum 5', 'status': 'pending'},
      ];

      final data = AlumniDailyOutreachDataModel.fromJson({
        'groupName': 'Param',
        'date': '2026-11-16',
        'targetDailyCount': 5,
        'contactedTodayCount': 2,
        'totalAlumniInGroup': 140,
        'totalMessagedAlumni': 42,
        'messageTemplate': 'Jai Swaminarayan {name} from {group_name}',
        'students': studentsJson,
      });

      expect(data.groupName, 'Param');
      expect(data.students.length, 5);
      expect(data.contactedTodayCount, 2);
      expect(data.targetDailyCount, 5);
      expect(data.progressRatio, 0.4);
      expect(data.isAllCompleted, false);

      final completedData = AlumniDailyOutreachDataModel(
        groupName: 'Param',
        date: '2026-11-16',
        targetDailyCount: 5,
        contactedTodayCount: 5,
      );
      expect(completedData.progressRatio, 1.0);
      expect(completedData.isAllCompleted, true);
    });

    test('Template placeholder formatting substitutes correctly', () {
      const template =
          'Jai Swaminarayan {first_name} bhai! 🙏 Greetings from Hari Saurabh Hostel ({group_name} Group, past room {room}). - {leader_name}';

      final student = const AlumniOutreachStudentModel(
        studentId: 501,
        name: 'Pratik Patel',
        pastRoom: '305',
        groupName: 'Pulkit',
      );

      final firstName = student.name.trim().split(RegExp(r'\s+')).first;
      const leaderName = 'Rahul Leader';

      final formatted = template
          .replaceAll(RegExp(r'{name}', caseSensitive: false), student.name)
          .replaceAll(RegExp(r'{first_name}', caseSensitive: false), firstName)
          .replaceAll(RegExp(r'{group_name}', caseSensitive: false), student.groupName)
          .replaceAll(RegExp(r'{room}', caseSensitive: false), student.pastRoom)
          .replaceAll(RegExp(r'{leader_name}', caseSensitive: false), leaderName);

      expect(
        formatted,
        'Jai Swaminarayan Pratik bhai! 🙏 Greetings from Hari Saurabh Hostel (Pulkit Group, past room 305). - Rahul Leader',
      );
    });

    test('AlumniOutreachHistoryModel parses correctly from JSON', () {
      final json = {
        'id': 1,
        'studentId': 99,
        'name': 'Kishan Dave',
        'pastRoom': '101',
        'groupName': 'Pavitra',
        'outreachDate': '2026-11-16',
        'contactedAt': '2026-11-16 10:30:00',
        'message': 'Jai Swaminarayan Kishan bhai',
        'leaderName': 'Aman Patel',
      };

      final history = AlumniOutreachHistoryModel.fromJson(json);

      expect(history.id, 1);
      expect(history.studentId, 99);
      expect(history.name, 'Kishan Dave');
      expect(history.groupName, 'Pavitra');
      expect(history.leaderName, 'Aman Patel');
      expect(history.outreachDate, '2026-11-16');
      expect(history.whatsappReachability, 'not_verified');
    });

    test('contact status and number use the server values', () {
      final history = AlumniOutreachHistoryModel.fromJson({
        'id': 1,
        'studentId': 99,
        'whatsappNumber': '+91 90000 00000',
        'whatsappReachability': 'not_reachable',
      });
      expect(history.whatsappNumber, '+91 90000 00000');
      expect(history.whatsappReachability, 'not_reachable');
    });
  });
}
