import 'package:flutter/material.dart';

class CollapsibleCard extends StatefulWidget {
  final String title;
  final String icon;
  final List<Widget> children;
  final Color? accentColor;
  final int? badgeCount;
  final VoidCallback? onTap;

  const CollapsibleCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.accentColor,
    this.badgeCount,
    this.onTap,
  });

  @override
  State<CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? const Color(0xFF0D7377);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: _expanded ? 3 : 1,
      shadowColor: accent.withValues(alpha: 0.2),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(widget.icon, style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: accent, height: 1.2),
                        ),
                        if (widget.badgeCount != null) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.badgeCount} items',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accent),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    widget.onTap != null ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
                    color: accent,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (widget.onTap == null)
            SizeTransition(
              sizeFactor: _anim,
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: accent.withValues(alpha: 0.25), width: 3),
                    bottom: BorderSide(color: accent.withValues(alpha: 0.08), width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.children,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
