import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/models/birthday/birthday_models.dart';
import 'package:hsh_app2/core/network/repository/birthday/birthday_repository.dart';
import 'package:hsh_app2/features/birthday/bindings/admin_birthday_binding.dart';
import 'package:hsh_app2/features/birthday/controllers/admin_birthday_controller.dart';
import 'package:hsh_app2/features/birthday/views/admin_birthday_screen.dart';

void main() {
  group('Birthday Models & Serialization', () {
    test('BirthdayConfigModel parses JSON correctly', () {
      final json = {
        'id': 1,
        'isEnabled': true,
        'sendTime': '08:30',
        'targetAudience': 'student_only',
        'preferWhatsAppNumber': true,
        'adminNotificationPhone': '9876543210',
        'messageTemplate': 'Happy Birthday {first_name}!',
        'imageUrl': 'https://example.com/card.jpg',
        'lastRunDate': '2026-10-15',
      };

      final config = BirthdayConfigModel.fromJson(json);
      expect(config.id, 1);
      expect(config.isEnabled, true);
      expect(config.sendTime, '08:30');
      expect(config.targetAudience, 'student_only');
      expect(config.adminNotificationPhone, '9876543210');
      expect(config.messageTemplate, 'Happy Birthday {first_name}!');
    });

    test('BirthdayStudentModel handles Room N/A properly', () {
      final json = {
        'studentId': 178038,
        'name': 'AADHYA VIJAYKUMAR DAVE',
        'studentCode': '0873',
        'phone': '9824803024',
        'whatsappNumber': '9824803024',
        'room': 'N/A',
        'dob': '2005-05-06',
        'isActive': false,
      };

      final student = BirthdayStudentModel.fromJson(json);
      expect(student.studentId, 178038);
      expect(student.name, 'AADHYA VIJAYKUMAR DAVE');
      expect(student.room, 'N/A');
      expect(student.dob, '2005-05-06');
      expect(student.isActive, false);
    });

    test('BirthdayDashboardData parses full payload', () {
      final json = {
        'config': {
          'id': 1,
          'isEnabled': true,
          'sendTime': '08:00',
        },
        'todaysBirthdays': [
          {
            'studentId': 101,
            'name': 'Krutarth Patel',
            'studentCode': 'HSH-102',
            'room': '204',
          }
        ],
        'tomorrowsBirthdays': [
          {
            'studentId': 105,
            'name': 'Rahul Sharma',
            'studentCode': 'HSH-105',
            'room': '306',
          }
        ],
        'recentLogs': [],
        'isWhatsAppConnected': true,
        'senderPhone': '919999999999',
      };

      final dashboard = BirthdayDashboardData.fromJson(json);
      expect(dashboard.isWhatsAppConnected, true);
      expect(dashboard.todaysBirthdays.length, 1);
      expect(dashboard.tomorrowsBirthdays.length, 1);
      expect(dashboard.todaysBirthdays.first.name, 'Krutarth Patel');
      expect(dashboard.tomorrowsBirthdays.first.name, 'Rahul Sharma');
    });
  });
}
