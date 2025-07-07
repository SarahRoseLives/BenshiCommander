enum CommandGroup {
  BASIC(2),
  EXTENDED(10);

  const CommandGroup(this.value);
  final int value;
  static CommandGroup fromInt(int val) => CommandGroup.values.firstWhere((e) => e.value == val, orElse: () => CommandGroup.BASIC);
}

enum BasicCommand {
  UNKNOWN(0),
  GET_DEV_INFO(4),
  READ_STATUS(5),
  REGISTER_NOTIFICATION(6),
  EVENT_NOTIFICATION(9),
  READ_RF_CH(13),
  GET_HT_STATUS(20),
  GET_POSITION(76);

  const BasicCommand(this.value);
  final int value;
  static BasicCommand fromInt(int val) => BasicCommand.values.firstWhere((e) => e.value == val, orElse: () => BasicCommand.UNKNOWN);
}

enum ExtendedCommand {
  UNKNOWN(0),
  GET_DEV_STATE_VAR(16387);

  const ExtendedCommand(this.value);
  final int value;
  static ExtendedCommand fromInt(int val) => ExtendedCommand.values.firstWhere((e) => e.value == val, orElse: () => ExtendedCommand.UNKNOWN);
}

enum EventType {
  UNKNOWN(0),
  HT_STATUS_CHANGED(1),
  DATA_RXD(2),
  HT_CH_CHANGED(5),
  HT_SETTINGS_CHANGED(6),
  POSITION_CHANGE(13);

  const EventType(this.value);
  final int value;
  static EventType fromInt(int val) =>
      EventType.values.firstWhere((e) => e.value == val, orElse: () => EventType.UNKNOWN);
}

enum PowerStatusType {
  BATTERY_LEVEL(1),
  BATTERY_VOLTAGE(2),
  RC_BATTERY_LEVEL(3),
  BATTERY_LEVEL_AS_PERCENTAGE(4);

  const PowerStatusType(this.value);
  final int value;
}

enum ChannelType {
  OFF(0),
  A(1),
  B(2);

  const ChannelType(this.value);
  final int value;
  static ChannelType fromInt(int val) =>
      ChannelType.values.firstWhere((e) => e.value == val, orElse: () => ChannelType.OFF);
}

enum ReplyStatus {
  SUCCESS(0), FAILURE(1);
  const ReplyStatus(this.value);
  final int value;
  static ReplyStatus fromInt(int value) => ReplyStatus.values.firstWhere((e) => e.value == value, orElse: () => ReplyStatus.FAILURE);
}