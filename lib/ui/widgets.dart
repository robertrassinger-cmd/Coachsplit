part of coachsplit;

class _Stats extends StatelessWidget {
  const _Stats({required this.event});
  final RaceEvent? event;

  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final athletes = event?.athletes ?? [];
    final waiting = athletes.where((a) => a.status == AthleteStatus.waiting).length;
    final running = athletes.where((a) => a.status == AthleteStatus.running).length;
    final finished = athletes.where((a) => a.status == AthleteStatus.finished).length;
    final dnf = athletes.where((a) => a.status == AthleteStatus.didNotFinish).length;
    return Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Row(children: [
      Expanded(child: _Stat(label: 'warten', value: '$waiting')),
      const SizedBox(width: 8),
      Expanded(child: _Stat(label: 'unterwegs', value: '$running')),
      const SizedBox(width: 8),
      Expanded(child: _Stat(label: 'fertig', value: '$finished')),
      if (dnf > 0) ...[const SizedBox(width: 8), Expanded(child: _Stat(label: 'DNF', value: '$dnf'))],
    ]));
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(children: [Text(value, style: Theme.of(context).textTheme.titleLarge), Text(label, style: Theme.of(context).textTheme.labelSmall)])));
}


class CoachSplitLogo extends StatelessWidget {
  const CoachSplitLogo({super.key, this.size = 34, this.showText = false});

  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF07121F),
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: const Color(0xFF2F8CFF), width: max(1.0, size * 0.055)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.timer_outlined, color: const Color(0xFF2F8CFF), size: size * 0.62),
          Positioned(
            bottom: size * 0.15,
            child: Text(
              'CS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.28,
                letterSpacing: -1,
              ),
            ),
          ),
        ],
      ),
    );

    if (!showText) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            children: [
              TextSpan(text: 'Coach'),
              TextSpan(text: 'Split', style: TextStyle(color: Color(0xFF2F8CFF))),
            ],
          ),
        ),
      ],
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.selected, required this.onChanged, this.setupLocked = false});
  final int selected;
  final ValueChanged<int> onChanged;
  final bool setupLocked;

  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final items = const [(Icons.settings, 'Setup'), (Icons.play_arrow, 'Start'), (Icons.touch_app, 'Erfassen'), (Icons.leaderboard, 'Ergebnis')];
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: SegmentedButton<int>(segments: [for (var i = 0; i < items.length; i++) ButtonSegment(value: i, enabled: !(setupLocked && i == 0), icon: Icon(items[i].$1, size: 18), label: Text(items[i].$2))], selected: {selected}, onSelectionChanged: (s) => onChanged(s.first)));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), Text(subtitle, style: Theme.of(context).textTheme.bodySmall), const Divider(), child])));
}

class _AthletePreview extends StatelessWidget {
  const _AthletePreview({required this.event, required this.onEditStart, required this.onRemove});
  final RaceEvent? event;
  final Future<void> Function(Athlete athlete) onEditStart;
  final void Function(Athlete athlete) onRemove;

  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final athletes = event?.athletes ?? [];
    if (athletes.isEmpty) return const Text('Keine Athleten geladen');
    return Column(children: [for (final a in athletes) ListTile(dense: true, leading: _Bib(bib: a.bib), title: Text(a.name), subtitle: Text('${a.category} · Start ${_clock(a.scheduledStart)}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: () => onEditStart(a)),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => onRemove(a)),
          ]))]);
  }
  String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

class _StartRow extends StatelessWidget {
  const _StartRow({
    required this.athlete,
    required this.autoStartEnabled,
    required this.currentCompetitionTime,
    required this.onStart,
  });

  final Athlete athlete;
  final bool autoStartEnabled;
  final DateTime currentCompetitionTime;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final diff = athlete.scheduledStart.difference(currentCompetitionTime);
    final late = diff.isNegative;

    return Card(
      child: ListTile(
        dense: true,
        leading: _Bib(bib: athlete.bib),
        title: Text(
          athlete.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(athlete.category),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (autoStartEnabled) ...[
              Text(
                late ? '+${_countdown(diff.abs())}' : _countdown(diff),
                style: TextStyle(
                  color: late ? Colors.redAccent : Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton(
              onPressed: onStart,
              child: const Text('START'),
            ),
          ],
        ),
      ),
    );
  }

  String _countdown(Duration d) {
    final totalSeconds = d.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _CaptureRow extends StatelessWidget {
  const _CaptureRow({
    required this.candidate,
    required this.etaText,
    required this.liveGapText,
    required this.onTap,
  });

  final Candidate candidate;
  final String etaText;
  final String liveGapText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasEta = candidate.predictedTime != null;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              _Bib(bib: candidate.athlete.bib, large: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.athlete.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${candidate.athlete.category}${candidate.athlete.isOwn ? ' · ★' : ''} · ${hasEta ? etaText : '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                liveGapText,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.point,
    required this.rows,
    required this.compareByCategory,
    required this.fmt,
    required this.shootingResultFor,
  });

  final SplitPoint point;
  final List<RankRow> rows;
  final bool compareByCategory;
  final String Function(Duration) fmt;
  final ShootingResult? Function(Athlete athlete) shootingResultFor;

  String get _pointTitle {
    if (point.type != PointType.shootingExit) return point.name;
    final position = point.shootingPosition == ShootingPosition.standing
        ? 'stehend'
        : 'liegend';
    return '${point.name} ($position)';
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('Noch keine Zeiten erfasst'));
    }

    final groups = <String, List<RankRow>>{};
    for (final row in rows) {
      final key = compareByCategory ? row.athlete.category : 'ALLE';
      groups.putIfAbsent(key, () => []).add(row);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (point.type == PointType.shootingExit)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _pointTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        for (final entry in groups.entries)
          _Section(
            title: entry.key,
            subtitle: point.type == PointType.finish
                ? 'Zielwertung'
                : point.type == PointType.shootingExit
                    ? 'Gewertete Zeit inklusive Schießfehler'
                    : 'Gesamtzeit + letzter Abschnitt',
            child: Column(
              children: [
                for (final row in entry.value)
                  ListTile(
                    leading: _Bib(bib: row.athlete.bib),
                    title: Text(row.athlete.name),
                    subtitle: Text(
                      point.type == PointType.finish
                          ? '${row.athlete.category} · Zeit ${fmt(row.elapsed)}'
                          : '${row.athlete.category} · Gesamt ${fmt(row.elapsed)}'
                              ' · Abschnitt ${row.sectionElapsed == null ? '—' : '${fmt(row.sectionElapsed!)} (${row.sectionPlace ?? row.place})'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (point.type == PointType.shootingExit) ...[
                          _MissBadge(
                            misses: shootingResultFor(row.athlete)?.misses,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Pl ${row.place}'),
                            Text(
                              row.deltaToLeader == Duration.zero
                                  ? 'führend'
                                  : '+${fmt(row.deltaToLeader)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MissBadge extends StatelessWidget {
  const _MissBadge({required this.misses});
  final int? misses;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Text(
        misses == null ? '–' : '$misses',
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _Bib extends StatelessWidget {
  const _Bib({required this.bib, this.large = false});
  final int bib;
  final bool large;
  @override
  Widget build(BuildContext context) => CircleAvatar(radius: large ? 23 : 20, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Text('$bib', style: TextStyle(fontWeight: FontWeight.w900, fontSize: large ? 18 : 15)));
}
