enum ActivityType { training, race, performanceTest, timeTrial, other }

enum ActivityStatus { draft, running, completed, archived, cancelled }

enum RouteType { trainingCourse, competitionCourse, testCourse, custom }

enum RoutePointType {
  start,
  split,
  shootingEntry,
  shootingExit,
  custom,
  finish,
}

enum ParticipationStatus {
  registered,
  started,
  racing,
  finished,
  didNotFinish,
  didNotStart,
  disqualified,
}

enum TimingEventKind {
  start,
  split,
  shootingEntry,
  shootingExit,
  finish,
  correction,
  didNotFinish,
}

enum ShootingPositionV2 { prone, standing }

enum SyncState { localOnly, pending, synced, conflict, failed }
