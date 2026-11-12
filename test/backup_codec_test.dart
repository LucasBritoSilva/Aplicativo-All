import 'package:aplicativo_all/core/backup/backup_codec.dart';
import 'package:aplicativo_all/core/backup/backup_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupSnapshot', () {
    final snapshot = BackupSnapshot(
      schemaVersion: 1,
      exportedAt: DateTime.utc(2026, 11, 11, 17, 30),
      tables: {
        'tasks': [
          {'id': 1, 'title': 'Pagar conta', 'done': 0, 'due_date': null},
        ],
        'goals': [
          {'id': 3, 'current_value': 2.5, 'target_value': 10.0},
        ],
      },
    );

    test('ida e volta preserva os dados', () {
      final decoded = BackupSnapshot.decode(snapshot.encode());
      expect(decoded.schemaVersion, 1);
      expect(decoded.exportedAt.toUtc(), DateTime.utc(2026, 11, 11, 17, 30));
      expect(decoded.tables['tasks'], snapshot.tables['tasks']);
      expect(decoded.tables['goals']!.first['current_value'], 2.5);
      expect(decoded.totalRows, 2);
    });

    test('recusa arquivo de outro app', () {
      expect(
        () => BackupSnapshot.decode('{"app":"outro","format":1}'),
        throwsFormatException,
      );
    });

    test('recusa JSON corrompido', () {
      expect(() => BackupSnapshot.decode('{"app":'), throwsFormatException);
    });

    test('recusa formato mais novo', () {
      expect(
        () => BackupSnapshot.decode(
          '{"app":"aplicativo_all","format":99,"schemaVersion":1,'
          '"exportedAt":"2026-11-11T00:00:00Z","tables":{}}',
        ),
        throwsFormatException,
      );
    });

    test('recusa valores aninhados nas linhas', () {
      expect(
        () => BackupSnapshot.decode(
          '{"app":"aplicativo_all","format":1,"schemaVersion":1,'
          '"exportedAt":"2026-11-11T00:00:00Z",'
          '"tables":{"tasks":[{"id":{"x":1}}]}}',
        ),
        throwsFormatException,
      );
    });
  });

  group('BackupConfig', () {
    test('vazio = não configurado', () {
      expect(
        BackupConfig.parse('{"android_client_id": ""}').isConfigured,
        isFalse,
      );
      expect(BackupConfig.parse('lixo').isConfigured, isFalse);
    });

    test('ID no formato do Google = configurado', () {
      expect(
        BackupConfig.parse(
          '{"android_client_id": " 123-abc.apps.googleusercontent.com "}',
        ).isConfigured,
        isTrue,
      );
    });
  });
}
