import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/services/student_photo_cache_service.dart';
import '../../../core/utils/string_formatting.dart';

/// Reusable executive student contact card featuring the signature
/// organic corner wave, squircle avatar, light metadata chips,
/// and quick-action communication controls.
class StudentContactCard extends StatelessWidget {
  final String name;
  final String? room;
  final String? groupName;
  final String? bankCode;

  /// Photo for the avatar; the first letter shows while it loads or when it
  /// can't be loaded.
  final String? photoUrl;
  final String? dobText;
  final String primaryPhone;
  final String? whatsappNumber;
  final bool isAlumni;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isFavourite;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleFavourite;
  final ValueChanged<String>? onCall;
  final ValueChanged<String>? onWhatsApp;
  final VoidCallback? onShare;
  final Widget? customSubtitle;
  final Widget? statusPill;
  final List<Widget>? extraChips;
  final EdgeInsetsGeometry? margin;

  const StudentContactCard({
    super.key,
    required this.name,
    this.room,
    this.groupName,
    this.bankCode,
    this.photoUrl,
    this.dobText,
    required this.primaryPhone,
    this.whatsappNumber,
    this.isAlumni = false,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.isFavourite = false,
    required this.onTap,
    this.onLongPress,
    this.onToggleFavourite,
    this.onCall,
    this.onWhatsApp,
    this.onShare,
    this.customSubtitle,
    this.statusPill,
    this.extraChips,
    this.margin,
  });

  /// The photo when there is one, else the student's first letter.
  Widget _avatarContent(String displayName, Color color) {
    final letter = Text(
      displayName.isNotEmpty
          ? displayName[0].toUpperCase()
          : (name.isNotEmpty ? name[0].toUpperCase() : 'S'),
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 21),
    );
    final url = photoUrl;
    if (url == null) return letter;
    return StudentPhoto(
      url: url,
      name: displayName.isNotEmpty ? displayName : name,
      letter: letter,
      onFallbackTap: onTap,
    );
  }

  /// Group accent color
  static Color groupColor(String? group) {
    switch (group?.toLowerCase().trim()) {
      case 'param':
        return const Color(0xFF0284C7);
      case 'pavitra':
        return const Color(0xFF6366F1);
      case 'pulkit':
        return const Color(0xFFEA580C);
      case 'paramanand':
        return const Color(0xFF0D9488);
      case 'alumni':
        return const Color(0xFF9333EA);
      default:
        return const Color(0xFF0284C7);
    }
  }

  /// Group soft background tint
  static Color groupBgColor(String? group) {
    switch (group?.toLowerCase().trim()) {
      case 'param':
        return const Color(0xFFE0F2FE);
      case 'pavitra':
        return const Color(0xFFEEF2FF);
      case 'pulkit':
        return const Color(0xFFFFEDD5);
      case 'paramanand':
        return const Color(0xFFCCFBF1);
      case 'alumni':
        return const Color(0xFFF3E8FF);
      default:
        return const Color(0xFFE0F2FE);
    }
  }

  /// Pastel wave tint matching the celebrant signature palette
  static Color waveColor(String? group, {bool isAlumni = false}) {
    if (isAlumni) return const Color(0xFFE9D5FF);
    switch (group?.toLowerCase().trim()) {
      case 'param':
        return const Color(0xFFBAE6FD);
      case 'pavitra':
        return const Color(0xFFC7D2FE);
      case 'pulkit':
        return const Color(0xFFFED7AA);
      case 'paramanand':
        return const Color(0xFF99F6E4);
      case 'alumni':
        return const Color(0xFFE9D5FF);
      default:
        return const Color(0xFFBAE6FD);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = formatPersonName(name);
    final gColor = isAlumni ? const Color(0xFF9333EA) : groupColor(groupName);
    final gBg = isAlumni ? const Color(0xFFF3E8FF) : groupBgColor(groupName);
    final wave = waveColor(groupName, isAlumni: isAlumni);
    final hasPhone = primaryPhone != 'No Phone' && primaryPhone.isNotEmpty;

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
          width: isSelected ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF0284C7).withValues(alpha: 0.1)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Bottom-right organic corner wave (celebrant signature)
              Positioned(
                bottom: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(70, 48),
                  painter: CornerWavePainter(
                    color: wave.withValues(alpha: 0.45),
                  ),
                ),
              ),

              // Card content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    // Squircle avatar
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelectionMode
                                ? (isSelected
                                      ? const Color(0xFF0284C7)
                                      : const Color(0xFFF1F5F9))
                                : gBg,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: isSelectionMode
                                  ? (isSelected
                                        ? const Color(0xFF0284C7)
                                        : const Color(0xFFCBD5E1))
                                  : gColor.withValues(alpha: 0.25),
                              width: isSelectionMode && isSelected ? 2 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: isSelectionMode
                              ? Icon(
                                  isSelected
                                      ? Icons.check_rounded
                                      : Icons.circle_outlined,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF94A3B8),
                                  size: 20,
                                )
                              : _avatarContent(displayName, gColor),
                        ),
                        if (!isSelectionMode)
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: gColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                isAlumni
                                    ? Icons.school_rounded
                                    : Icons.person_rounded,
                                color: Colors.white,
                                size: 8,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(width: 12),

                    // Name + Room Number
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.isNotEmpty ? displayName : name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3.5),
                          if (customSubtitle != null)
                            customSubtitle!
                          else
                            _buildMetadataRow(gColor, gBg, isAlumni),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Actions: Favourite Star + Small WhatsApp + Small Call
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (statusPill != null) ...[
                          statusPill!,
                          const SizedBox(width: 4),
                        ],
                        if (onToggleFavourite != null) ...[
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isSelectionMode ? onTap : onToggleFavourite,
                              borderRadius: BorderRadius.circular(16),
                              child: Tooltip(
                                message: isFavourite ? 'Remove from Favourites' : 'Add to Favourites',
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Icon(
                                    isFavourite ? Icons.star_rounded : Icons.star_outline_rounded,
                                    size: 20,
                                    color: isFavourite ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                        ],
                        if (hasPhone && onWhatsApp != null) ...[
                          _SmallActionButton(
                            icon: const FaIcon(
                              FontAwesomeIcons.whatsapp,
                              size: 16,
                              color: Color(0xFF059669),
                            ),
                            bgColor: const Color(0xFFECFDF5),
                            borderColor: const Color(0xFFA7F3D0),
                            tooltip: isSelectionMode ? 'Select' : 'Chat on WhatsApp',
                            onTap: isSelectionMode
                                ? onTap
                                : () => onWhatsApp!(
                                    whatsappNumber?.isNotEmpty == true
                                        ? whatsappNumber!
                                        : primaryPhone,
                                  ),
                          ),
                        ],
                        if (hasPhone && onWhatsApp != null && onCall != null)
                          const SizedBox(width: 6),
                        if (hasPhone && onCall != null) ...[
                          _SmallActionButton(
                            icon: const Icon(
                              Icons.phone_rounded,
                              size: 16,
                              color: Color(0xFF0284C7),
                            ),
                            bgColor: const Color(0xFFE0F2FE),
                            borderColor: const Color(0xFFBAE6FD),
                            tooltip: isSelectionMode ? 'Select' : 'Call Student ($primaryPhone)',
                            onTap: isSelectionMode ? onTap : () => onCall!(primaryPhone),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomChip(Color gColor, bool isAlumni) {
    final r = (room ?? '').trim();
    final bool hasRoom = r.isNotEmpty &&
        r.toLowerCase() != 'n/a' &&
        r.toLowerCase() != 'none' &&
        r.toLowerCase() != 'null';
    final String label = hasRoom
        ? (r.toLowerCase().startsWith('room') ? r : 'Room $r')
        : (isAlumni ? 'Alumni' : 'No Room');
    final bool showAlumniStyle = !hasRoom && isAlumni;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
      decoration: BoxDecoration(
        color: showAlumniStyle ? const Color(0xFFF3E8FF) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: showAlumniStyle ? const Color(0xFFE9D5FF) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            showAlumniStyle ? Icons.school_rounded : Icons.meeting_room_rounded,
            size: 11,
            color: showAlumniStyle ? const Color(0xFF9333EA) : const Color(0xFF475569),
          ),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: showAlumniStyle ? const Color(0xFF9333EA) : const Color(0xFF334155),
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupChip(Color gColor, Color gBg) {
    final group = (groupName ?? '').trim();
    if (group.isEmpty) return const SizedBox.shrink();
    if (isAlumni && group.toLowerCase() == 'alumni') return const SizedBox.shrink();

    final label = isAlumni ? 'Alumni' : group;
    final color = isAlumni ? const Color(0xFF9333EA) : gColor;
    final bg = isAlumni ? const Color(0xFFF3E8FF) : gBg;
    final borderColor = isAlumni ? const Color(0xFFE9D5FF) : color.withValues(alpha: 0.25);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.5,
            height: 5.5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(Color gColor, Color gBg, bool isAlumni) {
    final hasGroup = (groupName != null && groupName!.trim().isNotEmpty);
    final hasExtra = (bankCode != null && bankCode!.isNotEmpty) ||
        (dobText != null && dobText!.isNotEmpty) ||
        (extraChips != null && extraChips!.isNotEmpty);

    return Wrap(
      spacing: 5,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildRoomChip(gColor, isAlumni),
        if (hasGroup)
          _buildGroupChip(gColor, gBg),
        if (hasExtra) ...[
          if (bankCode != null && bankCode!.isNotEmpty)
            CelebrantLightChip(
              icon: Icons.tag_rounded,
              text: 'ID: $bankCode',
              bgColor: const Color(0xFFF8FAFC),
              borderColor: const Color(0xFFE2E8F0),
              textColor: const Color(0xFF475569),
            ),
          if (dobText != null && dobText!.isNotEmpty)
            CelebrantLightChip(
              icon: Icons.cake_outlined,
              text: dobText!,
              bgColor: const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFFDE68A),
              textColor: const Color(0xFFD97706),
            ),
          ...?extraChips,
        ],
      ],
    );
  }
}

/// Modular rounded chip used across celebrant and student contact cards
class CelebrantLightChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  const CelebrantLightChip({
    super.key,
    required this.icon,
    required this.text,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final Widget icon;
  final Color bgColor;
  final Color borderColor;
  final String tooltip;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1),
            ),
            alignment: Alignment.center,
            child: icon,
          ),
        ),
      ),
    );
  }
}

/// Organic corner wave painter matching the operator home & celebrant card signature
class CornerWavePainter extends CustomPainter {
  final Color color;

  const CornerWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.72,
      size.width * 0.55,
      size.height * 0.48,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.22,
      size.width,
      0,
    );
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CornerWavePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A student's photo. The letter shows while it loads and if it can't be
/// loaded (no photo on the server answers 403). Tapping a loaded photo opens it
/// full size; this tap wins over the surrounding card's own tap.
class StudentPhoto extends StatefulWidget {
  final String url;
  final String name;
  final Widget letter;
  final double size;
  final double radius;

  /// What a tap does while there is no photo to show: the card's own tap.
  final VoidCallback? onFallbackTap;

  const StudentPhoto({
    super.key,
    required this.url,
    required this.name,
    required this.letter,
    this.size = 48,
    this.radius = 14,
    this.onFallbackTap,
  });

  @override
  State<StudentPhoto> createState() => _StudentPhotoState();
}

class _StudentPhotoState extends State<StudentPhoto> {
  File? _file;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoadPhoto();
  }

  @override
  void didUpdateWidget(StudentPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _checkAndLoadPhoto();
    }
  }

  void _checkAndLoadPhoto() {
    if (widget.url.trim().isEmpty) {
      _file = null;
      _loaded = false;
      return;
    }

    // 1. Fast synchronous check: cached on local storage
    final cached = StudentPhotoCacheService.instance.getCachedFile(widget.url);
    if (cached != null) {
      _file = cached;
      _loaded = true;
      return;
    }

    // 2. Fast synchronous check: known missing (403/404)
    if (StudentPhotoCacheService.instance.isMarkedMissing(widget.url)) {
      _file = null;
      _loaded = false;
      return;
    }

    // 3. Otherwise fetch asynchronously and store in phone local
    _file = null;
    _loaded = false;
    StudentPhotoCacheService.instance.loadPhoto(widget.url).then((file) {
      if (!mounted) return;
      if (file != null) {
        setState(() {
          _file = file;
          _loaded = true;
        });
      }
    });
  }

  /// Remembers whether the photo is showing, and rebuilds so the tap handler
  /// follows (this runs while the image is building).
  void _setLoaded(bool value) {
    if (value == _loaded) return;
    _loaded = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Decided at tap time: whether the photo loaded is only known after
      // this widget was built.
      // No handler (null) lets the surrounding card take the tap.
      onTap: (_loaded || widget.onFallbackTap != null)
          ? () {
              if (_loaded) {
                showStudentPhotoDialog(
                  context,
                  url: widget.url,
                  name: widget.name,
                  localFile: _file,
                );
              } else {
                widget.onFallbackTap?.call();
              }
            }
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: _file != null
            ? Image.file(
                _file!,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
                // The files are large; decode them at avatar size.
                cacheWidth: (widget.size * 3).round(),
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  _setLoaded(frame != null || wasSynchronouslyLoaded);
                  return _loaded ? child : Center(child: widget.letter);
                },
                errorBuilder: (context, error, stack) {
                  _setLoaded(false);
                  return Center(child: widget.letter);
                },
              )
            : Center(child: widget.letter),
      ),
    );
  }
}

/// A student's photo in a popup: pinch to zoom, tap outside or the close
/// button to dismiss.
Future<void> showStudentPhotoDialog(
  BuildContext context, {
  required String url,
  required String name,
  File? localFile,
}) {
  final resolvedFile = localFile ?? StudentPhotoCacheService.instance.getCachedFile(url);

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: InteractiveViewer(
                maxScale: 4,
                child: resolvedFile != null
                    ? Image.file(
                        resolvedFile,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => const SizedBox(
                          height: 200,
                          child: Center(
                            child: Text(
                              'Photo not available',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      )
                    : FutureBuilder<File?>(
                        future: StudentPhotoCacheService.instance.loadPhoto(url),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 240,
                              child: Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            );
                          }
                          final file = snapshot.data;
                          if (file != null && file.existsSync()) {
                            return Image.file(file, fit: BoxFit.contain);
                          }
                          return const SizedBox(
                            height: 200,
                            child: Center(
                              child: Text(
                                'Photo not available',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}
