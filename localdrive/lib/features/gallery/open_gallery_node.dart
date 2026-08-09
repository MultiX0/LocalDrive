import '../../imports.dart';
import '../files/models/node_model.dart';

/// Opens whatever was tapped in the gallery.
///
/// The gallery used to send everything to the photo viewer, which can only draw
/// a still. A clip lives in the gallery too, and opening one there gave an error
/// while the same file opened fine from Files, because Files goes to the preview
/// screen that owns the player.
///
/// Both gallery layouts call this, so phone and desktop cannot disagree again.
void openGalleryNode(BuildContext context, NodeModel node) {
  final playable =
      node.category == FileCategory.video || node.category == FileCategory.audio;
  context.push(
    playable ? Routes.previewOf(node.id) : Routes.photo(node.id),
  );
}
