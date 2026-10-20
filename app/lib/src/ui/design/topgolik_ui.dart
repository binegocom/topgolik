import 'package:flutter/material.dart';

import '../../models/football_match.dart';

abstract final class StadiumColors {
  static const background = Color(0xFF030C13);
  static const surface = Color(0xFF0B1A25);
  static const raised = Color(0xFF112737);
  static const border = Color(0xFF203746);
  static const green = Color(0xFF28EC7B);
  static const muted = Color(0xFFA2B1BC);
  static const red = Color(0xFFFF344F);
}

class TopgolikWordmark extends StatelessWidget {
  const TopgolikWordmark({super.key, this.size = 23});
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size + 10, height: size + 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: StadiumColors.green, width: 1.6),
        ),
        child: const Icon(Icons.sports_soccer, color: Colors.white),
      ),
      const SizedBox(width: 7),
      Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Top', style: TextStyle(color: Colors.white, fontSize: size, fontStyle: FontStyle.italic, fontWeight: FontWeight.w900)),
          TextSpan(text: 'golik', style: TextStyle(color: StadiumColors.green, fontSize: size, fontStyle: FontStyle.italic, fontWeight: FontWeight.w900)),
        ]),
      ),
    ],
  );
}

class TopgolikPanel extends StatelessWidget {
  const TopgolikPanel({super.key, required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: StadiumColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: StadiumColors.border),
    ),
    child: child,
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction, this.icon});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 20, color: StadiumColors.green),
        const SizedBox(width: 9),
      ],
      Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
      if (actionLabel != null && onAction != null)
        TextButton(
          onPressed: onAction,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(actionLabel!, style: const TextStyle(color: StadiumColors.muted, fontSize: 12)),
            const Icon(Icons.chevron_right, color: StadiumColors.muted, size: 18),
          ]),
        ),
    ],
  );
}

class TopgolikPill extends StatelessWidget {
  const TopgolikPill({
    super.key, required this.label, required this.selected, required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label, style: TextStyle(
      color: selected ? StadiumColors.background : Colors.white,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      fontSize: 12,
    )),
    selected: selected,
    onSelected: (_) => onPressed(),
    showCheckmark: false,
    side: BorderSide(color: selected ? StadiumColors.green : StadiumColors.border),
    backgroundColor: StadiumColors.surface,
    selectedColor: StadiumColors.green,
    shape: const StadiumBorder(),
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
  );
}

// Keep the reference's capsule silhouette, without adding an external package.
class StadiumBorder extends OutlinedBorder {
  const StadiumBorder({super.side});
  @override
  OutlinedBorder copyWith({BorderSide? side}) => StadiumBorder(side: side ?? this.side);
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect.deflate(side.width), textDirection: textDirection);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)));
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(side.width / 2), const Radius.circular(24)), Paint()..color = side.color..style = PaintingStyle.stroke..strokeWidth = side.width);
  }
  @override
  ShapeBorder scale(double t) => StadiumBorder(side: side.scale(t));
}

class TeamCrest extends StatelessWidget {
  const TeamCrest({super.key, this.url, this.size = 29});
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url ?? '');
    final valid = uri?.scheme == 'https';
    return SizedBox(
      height: size, width: size,
      child: valid
          ? Image.network(
              url!, fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(Icons.shield_outlined, color: StadiumColors.muted),
            )
          : const Icon(Icons.shield_outlined, color: StadiumColors.muted),
    );
  }
}

class EmptyFootballState extends StatelessWidget {
  const EmptyFootballState({super.key, required this.title, this.details, this.onRetry, this.retryLabel});
  final String title;
  final String? details;
  final VoidCallback? onRetry;
  final String? retryLabel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 50),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.sports_soccer_outlined, color: StadiumColors.muted, size: 42),
      const SizedBox(height: 12),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      if (details != null) ...[
        const SizedBox(height: 7),
        Text(details!, textAlign: TextAlign.center, style: const TextStyle(color: StadiumColors.muted, fontSize: 13)),
      ],
      if (onRetry != null && retryLabel != null) ...[
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onRetry, child: Text(retryLabel!)),
      ],
    ]),
  );
}

class FootballMatchTile extends StatelessWidget {
  const FootballMatchTile({
    super.key, required this.match, required this.onTap,
    this.isFavorite = false, this.onFavorite,
  });
  final FootballMatch match;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final live = match.isLive;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 5, 10),
        child: Row(children: [
          SizedBox(
            width: 48,
            child: live
                ? Column(children: [
                    const Icon(Icons.sensors, color: StadiumColors.red, size: 17),
                    const SizedBox(height: 3),
                    Text(match.statusDetail?.isNotEmpty == true ? match.statusDetail! : 'LIVE',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StadiumColors.red, fontSize: 10, fontWeight: FontWeight.w800)),
                  ])
                : Text(
                    match.isFinished ? 'FT' : TimeOfDay.fromDateTime(match.startsAt).format(context),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: StadiumColors.muted, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(width: 7),
          Expanded(child: Column(children: [
            _team(match.home, live || match.isFinished),
            const SizedBox(height: 9),
            _team(match.away, live || match.isFinished),
          ])),
          IconButton(
            tooltip: 'Favorite',
            onPressed: onFavorite,
            icon: Icon(isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: isFavorite ? StadiumColors.green : StadiumColors.muted, size: 20),
          ),
        ]),
      ),
    );
  }

  Widget _team(TeamInfo team, bool hasScore) => Row(children: [
    TeamCrest(url: team.logoUrl, size: 22),
    const SizedBox(width: 8),
    Expanded(child: Text(team.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
    SizedBox(width: 24, child: Text(
      hasScore ? (team.score?.toString() ?? '–') : '–',
      textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    )),
  ]);
}

class LeagueMatchPanel extends StatelessWidget {
  const LeagueMatchPanel({
    super.key, required this.league, required this.matches, required this.onMatch,
    required this.favorites, required this.onFavorite, this.onLeague,
  });
  final LeagueInfo league;
  final List<FootballMatch> matches;
  final void Function(FootballMatch) onMatch;
  final Set<int> favorites;
  final void Function(int) onFavorite;
  final VoidCallback? onLeague;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TopgolikPanel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          onTap: onLeague,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Icon(Icons.emoji_events_outlined, size: 19, color: StadiumColors.green),
              const SizedBox(width: 10),
              Expanded(child: Text(league.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
              if (league.country != null)
                Flexible(child: Text(league.country!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: StadiumColors.muted, fontSize: 10))),
              if (onLeague != null) const Icon(Icons.chevron_right, color: StadiumColors.muted),
            ]),
          ),
        ),
        const Divider(color: StadiumColors.border, height: 1),
        for (final match in matches)
          FootballMatchTile(
            match: match,
            isFavorite: favorites.contains(match.id),
            onFavorite: () => onFavorite(match.id),
            onTap: () => onMatch(match),
          ),
      ]),
    ),
  );
}
