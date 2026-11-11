/// Where ending a ride has got to, in the order it happens.
enum RideEndStage {
  /// The host's request is being sent to the room.
  ending,

  /// Every rider's phone is saving their final record.
  savingRiders,

  /// The host is putting the ride summary together and saving it.
  generatingSummary,

  /// The summary is saved and the room has ended.
  complete,
}
