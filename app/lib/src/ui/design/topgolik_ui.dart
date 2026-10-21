import 'package:flutter/material.dart';

import '../../models/football_match.dart';

abstract final class StadiumColors {
  static const background = Color(0xFF080F1A);
  static const surface = Color(0xFF101D2D);
  static const raised = Color(0xFF192B40);
  static const border = Color(0xFF263A50);
  static const green = Color(0xFF42E0AD);
  static const blue = Color(0xFF5B9DFF);
  static const muted = Color(0xFF92A5BA);
  static const red = Color(0xFFFF6479);
}

class TopgolikWordmark extends StatelessWidget {
  const TopgolikWordmark({super.key, this.size = 23});
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size + 11,
        height: size + 11,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [StadiumColors.blue, Color(0xFF3474E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(11),
          boxShadow: const [
            BoxShadow(color: Color(0x334A8DFF), blurRadius: 16, offset: Offset(0, 5)),
          ],
        ),
        child: Icon(Icons.sports_soccer, color: Colors.white, size: size * .87),
      ),
      const SizedBox(width: 10),
      Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Top', style: TextStyle(
            color: Colors.white, fontSize: size, fontWeight: FontWeight.w900,
            letterSpacing: -.8,
          )),
          TextSpan(text: 'golik', style: TextStyle(
            color: StadiumColors.blue, fontSize: size, fontWeight: FontWeight.w900,
            letterSpacing: -.8,
          )),
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
  Widget build(BuildContext context) => Material(
    color: StadiumColors.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: StadiumColors.border),
    ),
    child: Padding(padding: padding, child: child),
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
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: StadiumColors.raised,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: StadiumColors.blue),
        ),
        const SizedBox(width: 9),
      ],
      Expanded(child: Text(
        title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -.25),
      )),
      if (actionLabel != null && onAction != null)
        TextButton(
          onPressed: onAction,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(actionLabel!, style: const TextStyle(color: StadiumColors.blue, fontSize: 12, fontWeight: FontWeight.w700)),
            const Icon(Icons.chevron_right_rounded, color: StadiumColors.blue, size: 17),
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
  Widget build(BuildContext context) => Material(
    color: selected ? StadiumColors.blue : StadiumColors.raised,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? StadiumColors.blue : StadiumColors.border,
          ),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : StadiumColors.muted,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12,
        )),
      ),
    ),
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
    return Container(
      height: size,
      width: size,
      padding: EdgeInsets.all(size >= 32 ? 5.0 : 3.0),
      decoration: BoxDecoration(
        color: StadiumColors.raised,
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: valid
          ? Image.network(
              url!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.shield_outlined, color: StadiumColors.muted,
              ),
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
    final hasScore = live || match.isFinished;
    final statusText = live
        ? (match.statusDetail?.isNotEmpty == true ? match.statusDetail! : 'LIVE')
        : match.isFinished
            ? 'FT'
            : TimeOfDay.fromDateTime(match.startsAt).format(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 5, 11),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (live)
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.only(bottom: 5),
                      decoration: const BoxDecoration(
                        color: StadiumColors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: live ? StadiumColors.red : StadiumColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 2,
              height: 41,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: live ? StadiumColors.red : StadiumColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _team(match.home, hasScore, live),
                  const SizedBox(height: 8),
                  _team(match.away, hasScore, live),
                ],
              ),
            ),
            SizedBox(
              width: 43,
              height: 48,
              child: IconButton(
                tooltip: 'Favorite',
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavorite ? StadiumColors.blue : StadiumColors.muted,
                  size: 21,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _team(TeamInfo team, bool hasScore, bool live) => Row(
    children: [
      TeamCrest(url: team.logoUrl, size: 24),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(width: 5),
      SizedBox(
        width: 23,
        child: Text(
          hasScore ? (team.score?.toString() ?? '–') : '–',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: live ? StadiumColors.green : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
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
      child: Column(
        children: [
          InkWell(
            onTap: onLeague,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: const BoxDecoration(color: StadiumColors.raised),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, size: 19, color: StadiumColors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          league.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                        if (league.country?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              league.country!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: StadiumColors.muted, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onLeague != null)
                    const Icon(Icons.chevron_right_rounded, color: StadiumColors.muted, size: 19),
                ],
              ),
            ),
          ),
          for (var index = 0; index < matches.length; index++) ...[
            if (index > 0)
              const Divider(height: 1, indent: 12, endIndent: 12, color: StadiumColors.border),
            FootballMatchTile(
              match: matches[index],
              isFavorite: favorites.contains(matches[index].id),
              onFavorite: () => onFavorite(matches[index].id),
              onTap: () => onMatch(matches[index]),
            ),
          ],
        ],
      ),
    ),
  );
}
