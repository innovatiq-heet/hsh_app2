import 'package:flutter/material.dart';
import '../../../core/utils/student_photo.dart';
import '../../phonebook/services/student_photo_directory.dart';
import 'student_contact_card.dart';

/// A student's avatar: their photo when one can be found, otherwise [child]
/// (the initials, tick or icon the screen already showed).
///
/// The photo comes from [aadhar] when given, else from the phonebook synced
/// on this phone by [bankCode] (display only, see [StudentPhotoDirectory]).
/// Tapping a loaded photo opens it full size.
class StudentAvatar extends StatefulWidget {
  final String name;
  final String? bankCode;
  final String? aadhar;
  final double size;
  final bool circle;
  final Color background;
  final Color? borderColor;
  final Widget child;

  /// Whose photo to show: the student's (default) or a parent's. Parent
  /// photos are found with the same [aadhar] / [bankCode] of the student.
  final PhotoOf photoOf;

  /// What a tap does while there is no photo; null leaves taps to the card.
  final VoidCallback? onFallbackTap;

  const StudentAvatar({
    super.key,
    required this.name,
    required this.child,
    required this.background,
    this.bankCode,
    this.aadhar,
    this.size = 44,
    this.circle = true,
    this.borderColor,
    this.onFallbackTap,
    this.photoOf = PhotoOf.student,
  });

  @override
  State<StudentAvatar> createState() => _StudentAvatarState();
}

class _StudentAvatarState extends State<StudentAvatar> {
  @override
  void initState() {
    super.initState();
    if (studentPhotoUrl(widget.aadhar) == null && (widget.bankCode ?? '').trim().isNotEmpty) {
      StudentPhotoDirectory.instance.ensureLoaded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: StudentPhotoDirectory.instance.version,
      builder: (context, _, _) {
        final url = familyPhotoUrl(widget.aadhar, widget.photoOf) ??
            StudentPhotoDirectory.instance.urlForBankCode(widget.bankCode, who: widget.photoOf);
        final radius = widget.circle ? widget.size / 2 : widget.size * 0.3;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.background,
            shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.circle ? null : BorderRadius.circular(radius),
            border: widget.borderColor == null ? null : Border.all(color: widget.borderColor!),
          ),
          alignment: Alignment.center,
          child: url == null
              ? widget.child
              : StudentPhoto(
                  url: url,
                  name: widget.name,
                  letter: widget.child,
                  size: widget.size,
                  radius: radius,
                  onFallbackTap: widget.onFallbackTap,
                ),
        );
      },
    );
  }
}
