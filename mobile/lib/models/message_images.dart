/// Reads a chat message's photos from MessageResource/GroupMessageResource.
///
/// `image_urls` lists every photo; a backend from before multi-photo
/// messages only sends the single `image_url`, which becomes a one-photo
/// list.
List<String> parseMessageImageUrls(Map<String, dynamic> json) {
  final urls = json['image_urls'];
  if (urls is List) return urls.cast<String>();

  final single = json['image_url'] as String?;
  return single == null ? const [] : [single];
}
