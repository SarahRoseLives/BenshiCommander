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
  CANCEL_NOTIFICATION(7),
  EVENT_NOTIFICATION(9),
  READ_SETTINGS(10),
  WRITE_SETTINGS(11),
  READ_RF_CH(13),
  WRITE_RF_CH(14),
  GET_IN_SCAN(15), // Add this command
  SET_IN_SCAN(16),
  GET_HT_STATUS(20),
  SET_POSITION(32),
  // FREQ_MODE_SET_PAR(35), // <-- REMOVED
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
  NEW_INQUIRY_DATA(3),
  RESTORE_FACTORY_SETTINGS(4),
  HT_CH_CHANGED(5),
  HT_SETTINGS_CHANGED(6),
  RINGING_STOPPED(7),
  RADIO_STATUS_CHANGED(8),
  USER_ACTION(9),
  SYSTEM_EVENT(10),
  BSS_SETTINGS_CHANGED(11),
  DATA_TXD(12),
  POSITION_CHANGE(13);

  const EventType(this.value);
  final int value;
  static EventType fromInt(int val) =>
      EventType.values.firstWhere((e) => e.value == val, orElse: () => EventType.UNKNOWN);
}

enum PowerStatusType {
  UNKNOWN(0),
  BATTERY_LEVEL(1),
  BATTERY_VOLTAGE(2),
  RC_BATTERY_LEVEL(3),
  BATTERY_LEVEL_AS_PERCENTAGE(4);

  const PowerStatusType(this.value);
  final int value;
   static PowerStatusType fromInt(int val) =>
      PowerStatusType.values.firstWhere((e) => e.value == val, orElse: () => PowerStatusType.UNKNOWN);
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
  SUCCESS(0),
  NOT_SUPPORTED(1),
  NOT_AUTHENTICATED(2),
  INSUFFICIENT_RESOURCES(3),
  AUTHENTICATING(4),
  INVALID_PARAMETER(5),
  INCORRECT_STATE(6),
  IN_PROGRESS(7),
  FAILURE(255); // A generic failure for UI purposes if needed

  const ReplyStatus(this.value);
  final int value;
  static ReplyStatus fromInt(int value) => ReplyStatus.values.firstWhere((e) => e.value == value, orElse: () => ReplyStatus.FAILURE);
}

enum ModulationType { FM, AM, DMR }
enum BandwidthType { NARROW, WIDE }