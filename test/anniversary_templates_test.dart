import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/models/anniversary/anniversary_models.dart';

void main() {
  group('AnniversaryConfigModel templates', () {
    test('parses the library and the active id', () {
      final config = AnniversaryConfigModel.fromJson({
        'anniversaryEnabled': true,
        'sendTime': '08:00',
        'anniversaryMessageTemplate': 'Warm body',
        'anniversaryTemplates': [
          {'id': 'a1', 'name': 'Warm', 'body': 'Warm body', 'audience': 'anniversary'},
          {'id': 'a2', 'name': 'Short', 'body': 'Short body'},
        ],
        'activeAnniversaryTemplateId': 'a1',
      });
      expect(config.templates.map((t) => t.id), ['a1', 'a2']);
      expect(config.templates.first.name, 'Warm');
      expect(config.activeTemplateId, 'a1');
    });

    test('an older server without a library gives an empty list and no active id', () {
      final config = AnniversaryConfigModel.fromJson({
        'anniversaryEnabled': true,
        'anniversaryMessageTemplate': 'Only message',
      });
      expect(config.templates, isEmpty);
      expect(config.activeTemplateId, isNull);
      expect(config.anniversaryMessageTemplate, 'Only message');
    });

    test('parses a library sent as a JSON string and drops rows without an id', () {
      final list = AnniversaryTemplate.listFromJson(
        '[{"id":"x","name":"N","body":"B"},{"name":"no id","body":"B"}]',
      );
      expect(list.map((t) => t.id), ['x']);
    });

    test('toJson sends the library, the active id and the active body, never an audience', () {
      final config = AnniversaryConfigModel(
        sendTime: '08:00',
        anniversaryMessageTemplate: 'Short body',
        templates: const [
          AnniversaryTemplate(id: 'a1', name: 'Warm', body: 'Warm body'),
          AnniversaryTemplate(id: 'a2', name: 'Short', body: 'Short body'),
        ],
        activeTemplateId: 'a2',
      );
      final json = config.toJson();
      expect(json['activeAnniversaryTemplateId'], 'a2');
      expect(json['anniversaryMessageTemplate'], 'Short body');
      final sent = json['anniversaryTemplates'] as List;
      expect(sent, hasLength(2));
      expect((sent.first as Map).keys, containsAll(['id', 'name', 'body']));
      expect((sent.first as Map).containsKey('audience'), isFalse);
    });
  });

  group('splitPersonName', () {
    test('first, middle and last name', () {
      final n = splitPersonName('Ramesh Kumar Patel');
      expect((n.first, n.middle, n.last), ('Ramesh', 'Kumar', 'Patel'));
    });

    test('two words have no middle name; several middle words are kept together', () {
      final two = splitPersonName('Sunita Patel');
      expect((two.first, two.middle, two.last), ('Sunita', '', 'Patel'));
      final many = splitPersonName('A B C D');
      expect((many.first, many.middle, many.last), ('A', 'B C', 'D'));
    });

    test('one word has no middle or last name; blank is all empty; extra spaces are ignored', () {
      final one = splitPersonName('Sunita');
      expect((one.first, one.middle, one.last), ('Sunita', '', ''));
      final blank = splitPersonName('   ');
      expect((blank.first, blank.middle, blank.last), ('', '', ''));
      final spaced = splitPersonName('  Ramesh   Kumar  Patel ');
      expect((spaced.first, spaced.middle, spaced.last), ('Ramesh', 'Kumar', 'Patel'));
    });
  });
}
