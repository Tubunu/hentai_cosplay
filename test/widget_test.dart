import 'package:flutter_test/flutter_test.dart';
import 'package:mzt_downloader/models/pack_item.dart';

void main() {
  test('PackItem inferAuthor test', () {
    final author1 = PackItem.inferAuthor('Cosplay - 樱花庄的白猫', {});
    expect(author1, 'Cosplay');

    final author2 = PackItem.inferAuthor('少女写真', {'author': 'Kitten'});
    expect(author2, 'Kitten');
  });

  test('PackItem resolveExt test', () {
    final ext1 = PackItem.resolveExt('https://domain.com/photo.png');
    expect(ext1, 'png');

    final ext2 = PackItem.resolveExt('https://domain.com/photo.webp?token=123');
    expect(ext2, 'webp');

    final ext3 = PackItem.resolveExt('/file/abc1234');
    expect(ext3, 'jpg');
  });
}
