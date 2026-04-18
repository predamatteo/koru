// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _typeCombinationsMeta = const VerificationMeta(
    'typeCombinations',
  );
  @override
  late final GeneratedColumn<int> typeCombinations = GeneratedColumn<int>(
    'type_combinations',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _onConditionsMeta = const VerificationMeta(
    'onConditions',
  );
  @override
  late final GeneratedColumn<int> onConditions = GeneratedColumn<int>(
    'on_conditions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _operatorMeta = const VerificationMeta(
    'operator',
  );
  @override
  late final GeneratedColumn<int> operator = GeneratedColumn<int>(
    'operator',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dayFlagsMeta = const VerificationMeta(
    'dayFlags',
  );
  @override
  late final GeneratedColumn<int> dayFlags = GeneratedColumn<int>(
    'day_flags',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(127),
  );
  static const VerificationMeta _blockNotificationsMeta =
      const VerificationMeta('blockNotifications');
  @override
  late final GeneratedColumn<bool> blockNotifications = GeneratedColumn<bool>(
    'block_notifications',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("block_notifications" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _blockLaunchMeta = const VerificationMeta(
    'blockLaunch',
  );
  @override
  late final GeneratedColumn<bool> blockLaunch = GeneratedColumn<bool>(
    'block_launch',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("block_launch" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _addNewApplicationsMeta =
      const VerificationMeta('addNewApplications');
  @override
  late final GeneratedColumn<bool> addNewApplications = GeneratedColumn<bool>(
    'add_new_applications',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("add_new_applications" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isLockedMeta = const VerificationMeta(
    'isLocked',
  );
  @override
  late final GeneratedColumn<bool> isLocked = GeneratedColumn<bool>(
    'is_locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastStartTimeMeta = const VerificationMeta(
    'lastStartTime',
  );
  @override
  late final GeneratedColumn<int> lastStartTime = GeneratedColumn<int>(
    'last_start_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _onUntilMeta = const VerificationMeta(
    'onUntil',
  );
  @override
  late final GeneratedColumn<int> onUntil = GeneratedColumn<int>(
    'on_until',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lockedUntilMeta = const VerificationMeta(
    'lockedUntil',
  );
  @override
  late final GeneratedColumn<int> lockedUntil = GeneratedColumn<int>(
    'locked_until',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lockAtMeta = const VerificationMeta('lockAt');
  @override
  late final GeneratedColumn<int> lockAt = GeneratedColumn<int>(
    'lock_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pausedUntilMeta = const VerificationMeta(
    'pausedUntil',
  );
  @override
  late final GeneratedColumn<int> pausedUntil = GeneratedColumn<int>(
    'paused_until',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _blockingModeMeta = const VerificationMeta(
    'blockingMode',
  );
  @override
  late final GeneratedColumn<int> blockingMode = GeneratedColumn<int>(
    'blocking_mode',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('NoIcon'),
  );
  static const VerificationMeta _blockUnsupportedBrowsersMeta =
      const VerificationMeta('blockUnsupportedBrowsers');
  @override
  late final GeneratedColumn<bool> blockUnsupportedBrowsers =
      GeneratedColumn<bool>(
        'block_unsupported_browsers',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("block_unsupported_browsers" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _blockAdultContentMeta = const VerificationMeta(
    'blockAdultContent',
  );
  @override
  late final GeneratedColumn<bool> blockAdultContent = GeneratedColumn<bool>(
    'block_adult_content',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("block_adult_content" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#5C8262'),
  );
  static const VerificationMeta _presetIdMeta = const VerificationMeta(
    'presetId',
  );
  @override
  late final GeneratedColumn<int> presetId = GeneratedColumn<int>(
    'preset_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    typeCombinations,
    onConditions,
    operator,
    dayFlags,
    blockNotifications,
    blockLaunch,
    addNewApplications,
    isEnabled,
    isLocked,
    lastStartTime,
    onUntil,
    lockedUntil,
    lockAt,
    pausedUntil,
    blockingMode,
    emoji,
    blockUnsupportedBrowsers,
    blockAdultContent,
    sortOrder,
    colorHex,
    presetId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Profile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('type_combinations')) {
      context.handle(
        _typeCombinationsMeta,
        typeCombinations.isAcceptableOrUnknown(
          data['type_combinations']!,
          _typeCombinationsMeta,
        ),
      );
    }
    if (data.containsKey('on_conditions')) {
      context.handle(
        _onConditionsMeta,
        onConditions.isAcceptableOrUnknown(
          data['on_conditions']!,
          _onConditionsMeta,
        ),
      );
    }
    if (data.containsKey('operator')) {
      context.handle(
        _operatorMeta,
        operator.isAcceptableOrUnknown(data['operator']!, _operatorMeta),
      );
    }
    if (data.containsKey('day_flags')) {
      context.handle(
        _dayFlagsMeta,
        dayFlags.isAcceptableOrUnknown(data['day_flags']!, _dayFlagsMeta),
      );
    }
    if (data.containsKey('block_notifications')) {
      context.handle(
        _blockNotificationsMeta,
        blockNotifications.isAcceptableOrUnknown(
          data['block_notifications']!,
          _blockNotificationsMeta,
        ),
      );
    }
    if (data.containsKey('block_launch')) {
      context.handle(
        _blockLaunchMeta,
        blockLaunch.isAcceptableOrUnknown(
          data['block_launch']!,
          _blockLaunchMeta,
        ),
      );
    }
    if (data.containsKey('add_new_applications')) {
      context.handle(
        _addNewApplicationsMeta,
        addNewApplications.isAcceptableOrUnknown(
          data['add_new_applications']!,
          _addNewApplicationsMeta,
        ),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('is_locked')) {
      context.handle(
        _isLockedMeta,
        isLocked.isAcceptableOrUnknown(data['is_locked']!, _isLockedMeta),
      );
    }
    if (data.containsKey('last_start_time')) {
      context.handle(
        _lastStartTimeMeta,
        lastStartTime.isAcceptableOrUnknown(
          data['last_start_time']!,
          _lastStartTimeMeta,
        ),
      );
    }
    if (data.containsKey('on_until')) {
      context.handle(
        _onUntilMeta,
        onUntil.isAcceptableOrUnknown(data['on_until']!, _onUntilMeta),
      );
    }
    if (data.containsKey('locked_until')) {
      context.handle(
        _lockedUntilMeta,
        lockedUntil.isAcceptableOrUnknown(
          data['locked_until']!,
          _lockedUntilMeta,
        ),
      );
    }
    if (data.containsKey('lock_at')) {
      context.handle(
        _lockAtMeta,
        lockAt.isAcceptableOrUnknown(data['lock_at']!, _lockAtMeta),
      );
    }
    if (data.containsKey('paused_until')) {
      context.handle(
        _pausedUntilMeta,
        pausedUntil.isAcceptableOrUnknown(
          data['paused_until']!,
          _pausedUntilMeta,
        ),
      );
    }
    if (data.containsKey('blocking_mode')) {
      context.handle(
        _blockingModeMeta,
        blockingMode.isAcceptableOrUnknown(
          data['blocking_mode']!,
          _blockingModeMeta,
        ),
      );
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    }
    if (data.containsKey('block_unsupported_browsers')) {
      context.handle(
        _blockUnsupportedBrowsersMeta,
        blockUnsupportedBrowsers.isAcceptableOrUnknown(
          data['block_unsupported_browsers']!,
          _blockUnsupportedBrowsersMeta,
        ),
      );
    }
    if (data.containsKey('block_adult_content')) {
      context.handle(
        _blockAdultContentMeta,
        blockAdultContent.isAcceptableOrUnknown(
          data['block_adult_content']!,
          _blockAdultContentMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('preset_id')) {
      context.handle(
        _presetIdMeta,
        presetId.isAcceptableOrUnknown(data['preset_id']!, _presetIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      typeCombinations: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_combinations'],
      )!,
      onConditions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}on_conditions'],
      )!,
      operator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}operator'],
      )!,
      dayFlags: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_flags'],
      )!,
      blockNotifications: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}block_notifications'],
      )!,
      blockLaunch: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}block_launch'],
      )!,
      addNewApplications: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}add_new_applications'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      isLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_locked'],
      )!,
      lastStartTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_start_time'],
      )!,
      onUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}on_until'],
      )!,
      lockedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}locked_until'],
      )!,
      lockAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lock_at'],
      )!,
      pausedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paused_until'],
      )!,
      blockingMode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blocking_mode'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      blockUnsupportedBrowsers: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}block_unsupported_browsers'],
      )!,
      blockAdultContent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}block_adult_content'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      )!,
      presetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preset_id'],
      ),
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class Profile extends DataClass implements Insertable<Profile> {
  final int id;
  final String title;
  final int typeCombinations;
  final int onConditions;
  final int operator;
  final int dayFlags;
  final bool blockNotifications;
  final bool blockLaunch;
  final bool addNewApplications;
  final bool isEnabled;
  final bool isLocked;
  final int lastStartTime;
  final int onUntil;
  final int lockedUntil;
  final int lockAt;
  final int pausedUntil;
  final int blockingMode;
  final String emoji;
  final bool blockUnsupportedBrowsers;
  final bool blockAdultContent;
  final int sortOrder;
  final String colorHex;
  final int? presetId;
  const Profile({
    required this.id,
    required this.title,
    required this.typeCombinations,
    required this.onConditions,
    required this.operator,
    required this.dayFlags,
    required this.blockNotifications,
    required this.blockLaunch,
    required this.addNewApplications,
    required this.isEnabled,
    required this.isLocked,
    required this.lastStartTime,
    required this.onUntil,
    required this.lockedUntil,
    required this.lockAt,
    required this.pausedUntil,
    required this.blockingMode,
    required this.emoji,
    required this.blockUnsupportedBrowsers,
    required this.blockAdultContent,
    required this.sortOrder,
    required this.colorHex,
    this.presetId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['type_combinations'] = Variable<int>(typeCombinations);
    map['on_conditions'] = Variable<int>(onConditions);
    map['operator'] = Variable<int>(operator);
    map['day_flags'] = Variable<int>(dayFlags);
    map['block_notifications'] = Variable<bool>(blockNotifications);
    map['block_launch'] = Variable<bool>(blockLaunch);
    map['add_new_applications'] = Variable<bool>(addNewApplications);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['is_locked'] = Variable<bool>(isLocked);
    map['last_start_time'] = Variable<int>(lastStartTime);
    map['on_until'] = Variable<int>(onUntil);
    map['locked_until'] = Variable<int>(lockedUntil);
    map['lock_at'] = Variable<int>(lockAt);
    map['paused_until'] = Variable<int>(pausedUntil);
    map['blocking_mode'] = Variable<int>(blockingMode);
    map['emoji'] = Variable<String>(emoji);
    map['block_unsupported_browsers'] = Variable<bool>(
      blockUnsupportedBrowsers,
    );
    map['block_adult_content'] = Variable<bool>(blockAdultContent);
    map['sort_order'] = Variable<int>(sortOrder);
    map['color_hex'] = Variable<String>(colorHex);
    if (!nullToAbsent || presetId != null) {
      map['preset_id'] = Variable<int>(presetId);
    }
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      title: Value(title),
      typeCombinations: Value(typeCombinations),
      onConditions: Value(onConditions),
      operator: Value(operator),
      dayFlags: Value(dayFlags),
      blockNotifications: Value(blockNotifications),
      blockLaunch: Value(blockLaunch),
      addNewApplications: Value(addNewApplications),
      isEnabled: Value(isEnabled),
      isLocked: Value(isLocked),
      lastStartTime: Value(lastStartTime),
      onUntil: Value(onUntil),
      lockedUntil: Value(lockedUntil),
      lockAt: Value(lockAt),
      pausedUntil: Value(pausedUntil),
      blockingMode: Value(blockingMode),
      emoji: Value(emoji),
      blockUnsupportedBrowsers: Value(blockUnsupportedBrowsers),
      blockAdultContent: Value(blockAdultContent),
      sortOrder: Value(sortOrder),
      colorHex: Value(colorHex),
      presetId: presetId == null && nullToAbsent
          ? const Value.absent()
          : Value(presetId),
    );
  }

  factory Profile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      typeCombinations: serializer.fromJson<int>(json['typeCombinations']),
      onConditions: serializer.fromJson<int>(json['onConditions']),
      operator: serializer.fromJson<int>(json['operator']),
      dayFlags: serializer.fromJson<int>(json['dayFlags']),
      blockNotifications: serializer.fromJson<bool>(json['blockNotifications']),
      blockLaunch: serializer.fromJson<bool>(json['blockLaunch']),
      addNewApplications: serializer.fromJson<bool>(json['addNewApplications']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      isLocked: serializer.fromJson<bool>(json['isLocked']),
      lastStartTime: serializer.fromJson<int>(json['lastStartTime']),
      onUntil: serializer.fromJson<int>(json['onUntil']),
      lockedUntil: serializer.fromJson<int>(json['lockedUntil']),
      lockAt: serializer.fromJson<int>(json['lockAt']),
      pausedUntil: serializer.fromJson<int>(json['pausedUntil']),
      blockingMode: serializer.fromJson<int>(json['blockingMode']),
      emoji: serializer.fromJson<String>(json['emoji']),
      blockUnsupportedBrowsers: serializer.fromJson<bool>(
        json['blockUnsupportedBrowsers'],
      ),
      blockAdultContent: serializer.fromJson<bool>(json['blockAdultContent']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      presetId: serializer.fromJson<int?>(json['presetId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'typeCombinations': serializer.toJson<int>(typeCombinations),
      'onConditions': serializer.toJson<int>(onConditions),
      'operator': serializer.toJson<int>(operator),
      'dayFlags': serializer.toJson<int>(dayFlags),
      'blockNotifications': serializer.toJson<bool>(blockNotifications),
      'blockLaunch': serializer.toJson<bool>(blockLaunch),
      'addNewApplications': serializer.toJson<bool>(addNewApplications),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'isLocked': serializer.toJson<bool>(isLocked),
      'lastStartTime': serializer.toJson<int>(lastStartTime),
      'onUntil': serializer.toJson<int>(onUntil),
      'lockedUntil': serializer.toJson<int>(lockedUntil),
      'lockAt': serializer.toJson<int>(lockAt),
      'pausedUntil': serializer.toJson<int>(pausedUntil),
      'blockingMode': serializer.toJson<int>(blockingMode),
      'emoji': serializer.toJson<String>(emoji),
      'blockUnsupportedBrowsers': serializer.toJson<bool>(
        blockUnsupportedBrowsers,
      ),
      'blockAdultContent': serializer.toJson<bool>(blockAdultContent),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'colorHex': serializer.toJson<String>(colorHex),
      'presetId': serializer.toJson<int?>(presetId),
    };
  }

  Profile copyWith({
    int? id,
    String? title,
    int? typeCombinations,
    int? onConditions,
    int? operator,
    int? dayFlags,
    bool? blockNotifications,
    bool? blockLaunch,
    bool? addNewApplications,
    bool? isEnabled,
    bool? isLocked,
    int? lastStartTime,
    int? onUntil,
    int? lockedUntil,
    int? lockAt,
    int? pausedUntil,
    int? blockingMode,
    String? emoji,
    bool? blockUnsupportedBrowsers,
    bool? blockAdultContent,
    int? sortOrder,
    String? colorHex,
    Value<int?> presetId = const Value.absent(),
  }) => Profile(
    id: id ?? this.id,
    title: title ?? this.title,
    typeCombinations: typeCombinations ?? this.typeCombinations,
    onConditions: onConditions ?? this.onConditions,
    operator: operator ?? this.operator,
    dayFlags: dayFlags ?? this.dayFlags,
    blockNotifications: blockNotifications ?? this.blockNotifications,
    blockLaunch: blockLaunch ?? this.blockLaunch,
    addNewApplications: addNewApplications ?? this.addNewApplications,
    isEnabled: isEnabled ?? this.isEnabled,
    isLocked: isLocked ?? this.isLocked,
    lastStartTime: lastStartTime ?? this.lastStartTime,
    onUntil: onUntil ?? this.onUntil,
    lockedUntil: lockedUntil ?? this.lockedUntil,
    lockAt: lockAt ?? this.lockAt,
    pausedUntil: pausedUntil ?? this.pausedUntil,
    blockingMode: blockingMode ?? this.blockingMode,
    emoji: emoji ?? this.emoji,
    blockUnsupportedBrowsers:
        blockUnsupportedBrowsers ?? this.blockUnsupportedBrowsers,
    blockAdultContent: blockAdultContent ?? this.blockAdultContent,
    sortOrder: sortOrder ?? this.sortOrder,
    colorHex: colorHex ?? this.colorHex,
    presetId: presetId.present ? presetId.value : this.presetId,
  );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      typeCombinations: data.typeCombinations.present
          ? data.typeCombinations.value
          : this.typeCombinations,
      onConditions: data.onConditions.present
          ? data.onConditions.value
          : this.onConditions,
      operator: data.operator.present ? data.operator.value : this.operator,
      dayFlags: data.dayFlags.present ? data.dayFlags.value : this.dayFlags,
      blockNotifications: data.blockNotifications.present
          ? data.blockNotifications.value
          : this.blockNotifications,
      blockLaunch: data.blockLaunch.present
          ? data.blockLaunch.value
          : this.blockLaunch,
      addNewApplications: data.addNewApplications.present
          ? data.addNewApplications.value
          : this.addNewApplications,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      isLocked: data.isLocked.present ? data.isLocked.value : this.isLocked,
      lastStartTime: data.lastStartTime.present
          ? data.lastStartTime.value
          : this.lastStartTime,
      onUntil: data.onUntil.present ? data.onUntil.value : this.onUntil,
      lockedUntil: data.lockedUntil.present
          ? data.lockedUntil.value
          : this.lockedUntil,
      lockAt: data.lockAt.present ? data.lockAt.value : this.lockAt,
      pausedUntil: data.pausedUntil.present
          ? data.pausedUntil.value
          : this.pausedUntil,
      blockingMode: data.blockingMode.present
          ? data.blockingMode.value
          : this.blockingMode,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      blockUnsupportedBrowsers: data.blockUnsupportedBrowsers.present
          ? data.blockUnsupportedBrowsers.value
          : this.blockUnsupportedBrowsers,
      blockAdultContent: data.blockAdultContent.present
          ? data.blockAdultContent.value
          : this.blockAdultContent,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      presetId: data.presetId.present ? data.presetId.value : this.presetId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('typeCombinations: $typeCombinations, ')
          ..write('onConditions: $onConditions, ')
          ..write('operator: $operator, ')
          ..write('dayFlags: $dayFlags, ')
          ..write('blockNotifications: $blockNotifications, ')
          ..write('blockLaunch: $blockLaunch, ')
          ..write('addNewApplications: $addNewApplications, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('isLocked: $isLocked, ')
          ..write('lastStartTime: $lastStartTime, ')
          ..write('onUntil: $onUntil, ')
          ..write('lockedUntil: $lockedUntil, ')
          ..write('lockAt: $lockAt, ')
          ..write('pausedUntil: $pausedUntil, ')
          ..write('blockingMode: $blockingMode, ')
          ..write('emoji: $emoji, ')
          ..write('blockUnsupportedBrowsers: $blockUnsupportedBrowsers, ')
          ..write('blockAdultContent: $blockAdultContent, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('colorHex: $colorHex, ')
          ..write('presetId: $presetId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    typeCombinations,
    onConditions,
    operator,
    dayFlags,
    blockNotifications,
    blockLaunch,
    addNewApplications,
    isEnabled,
    isLocked,
    lastStartTime,
    onUntil,
    lockedUntil,
    lockAt,
    pausedUntil,
    blockingMode,
    emoji,
    blockUnsupportedBrowsers,
    blockAdultContent,
    sortOrder,
    colorHex,
    presetId,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.title == this.title &&
          other.typeCombinations == this.typeCombinations &&
          other.onConditions == this.onConditions &&
          other.operator == this.operator &&
          other.dayFlags == this.dayFlags &&
          other.blockNotifications == this.blockNotifications &&
          other.blockLaunch == this.blockLaunch &&
          other.addNewApplications == this.addNewApplications &&
          other.isEnabled == this.isEnabled &&
          other.isLocked == this.isLocked &&
          other.lastStartTime == this.lastStartTime &&
          other.onUntil == this.onUntil &&
          other.lockedUntil == this.lockedUntil &&
          other.lockAt == this.lockAt &&
          other.pausedUntil == this.pausedUntil &&
          other.blockingMode == this.blockingMode &&
          other.emoji == this.emoji &&
          other.blockUnsupportedBrowsers == this.blockUnsupportedBrowsers &&
          other.blockAdultContent == this.blockAdultContent &&
          other.sortOrder == this.sortOrder &&
          other.colorHex == this.colorHex &&
          other.presetId == this.presetId);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<int> id;
  final Value<String> title;
  final Value<int> typeCombinations;
  final Value<int> onConditions;
  final Value<int> operator;
  final Value<int> dayFlags;
  final Value<bool> blockNotifications;
  final Value<bool> blockLaunch;
  final Value<bool> addNewApplications;
  final Value<bool> isEnabled;
  final Value<bool> isLocked;
  final Value<int> lastStartTime;
  final Value<int> onUntil;
  final Value<int> lockedUntil;
  final Value<int> lockAt;
  final Value<int> pausedUntil;
  final Value<int> blockingMode;
  final Value<String> emoji;
  final Value<bool> blockUnsupportedBrowsers;
  final Value<bool> blockAdultContent;
  final Value<int> sortOrder;
  final Value<String> colorHex;
  final Value<int?> presetId;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.typeCombinations = const Value.absent(),
    this.onConditions = const Value.absent(),
    this.operator = const Value.absent(),
    this.dayFlags = const Value.absent(),
    this.blockNotifications = const Value.absent(),
    this.blockLaunch = const Value.absent(),
    this.addNewApplications = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.lastStartTime = const Value.absent(),
    this.onUntil = const Value.absent(),
    this.lockedUntil = const Value.absent(),
    this.lockAt = const Value.absent(),
    this.pausedUntil = const Value.absent(),
    this.blockingMode = const Value.absent(),
    this.emoji = const Value.absent(),
    this.blockUnsupportedBrowsers = const Value.absent(),
    this.blockAdultContent = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.presetId = const Value.absent(),
  });
  ProfilesCompanion.insert({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.typeCombinations = const Value.absent(),
    this.onConditions = const Value.absent(),
    this.operator = const Value.absent(),
    this.dayFlags = const Value.absent(),
    this.blockNotifications = const Value.absent(),
    this.blockLaunch = const Value.absent(),
    this.addNewApplications = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.lastStartTime = const Value.absent(),
    this.onUntil = const Value.absent(),
    this.lockedUntil = const Value.absent(),
    this.lockAt = const Value.absent(),
    this.pausedUntil = const Value.absent(),
    this.blockingMode = const Value.absent(),
    this.emoji = const Value.absent(),
    this.blockUnsupportedBrowsers = const Value.absent(),
    this.blockAdultContent = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.presetId = const Value.absent(),
  });
  static Insertable<Profile> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<int>? typeCombinations,
    Expression<int>? onConditions,
    Expression<int>? operator,
    Expression<int>? dayFlags,
    Expression<bool>? blockNotifications,
    Expression<bool>? blockLaunch,
    Expression<bool>? addNewApplications,
    Expression<bool>? isEnabled,
    Expression<bool>? isLocked,
    Expression<int>? lastStartTime,
    Expression<int>? onUntil,
    Expression<int>? lockedUntil,
    Expression<int>? lockAt,
    Expression<int>? pausedUntil,
    Expression<int>? blockingMode,
    Expression<String>? emoji,
    Expression<bool>? blockUnsupportedBrowsers,
    Expression<bool>? blockAdultContent,
    Expression<int>? sortOrder,
    Expression<String>? colorHex,
    Expression<int>? presetId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (typeCombinations != null) 'type_combinations': typeCombinations,
      if (onConditions != null) 'on_conditions': onConditions,
      if (operator != null) 'operator': operator,
      if (dayFlags != null) 'day_flags': dayFlags,
      if (blockNotifications != null) 'block_notifications': blockNotifications,
      if (blockLaunch != null) 'block_launch': blockLaunch,
      if (addNewApplications != null)
        'add_new_applications': addNewApplications,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (isLocked != null) 'is_locked': isLocked,
      if (lastStartTime != null) 'last_start_time': lastStartTime,
      if (onUntil != null) 'on_until': onUntil,
      if (lockedUntil != null) 'locked_until': lockedUntil,
      if (lockAt != null) 'lock_at': lockAt,
      if (pausedUntil != null) 'paused_until': pausedUntil,
      if (blockingMode != null) 'blocking_mode': blockingMode,
      if (emoji != null) 'emoji': emoji,
      if (blockUnsupportedBrowsers != null)
        'block_unsupported_browsers': blockUnsupportedBrowsers,
      if (blockAdultContent != null) 'block_adult_content': blockAdultContent,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (colorHex != null) 'color_hex': colorHex,
      if (presetId != null) 'preset_id': presetId,
    });
  }

  ProfilesCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<int>? typeCombinations,
    Value<int>? onConditions,
    Value<int>? operator,
    Value<int>? dayFlags,
    Value<bool>? blockNotifications,
    Value<bool>? blockLaunch,
    Value<bool>? addNewApplications,
    Value<bool>? isEnabled,
    Value<bool>? isLocked,
    Value<int>? lastStartTime,
    Value<int>? onUntil,
    Value<int>? lockedUntil,
    Value<int>? lockAt,
    Value<int>? pausedUntil,
    Value<int>? blockingMode,
    Value<String>? emoji,
    Value<bool>? blockUnsupportedBrowsers,
    Value<bool>? blockAdultContent,
    Value<int>? sortOrder,
    Value<String>? colorHex,
    Value<int?>? presetId,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      typeCombinations: typeCombinations ?? this.typeCombinations,
      onConditions: onConditions ?? this.onConditions,
      operator: operator ?? this.operator,
      dayFlags: dayFlags ?? this.dayFlags,
      blockNotifications: blockNotifications ?? this.blockNotifications,
      blockLaunch: blockLaunch ?? this.blockLaunch,
      addNewApplications: addNewApplications ?? this.addNewApplications,
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
      lastStartTime: lastStartTime ?? this.lastStartTime,
      onUntil: onUntil ?? this.onUntil,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      lockAt: lockAt ?? this.lockAt,
      pausedUntil: pausedUntil ?? this.pausedUntil,
      blockingMode: blockingMode ?? this.blockingMode,
      emoji: emoji ?? this.emoji,
      blockUnsupportedBrowsers:
          blockUnsupportedBrowsers ?? this.blockUnsupportedBrowsers,
      blockAdultContent: blockAdultContent ?? this.blockAdultContent,
      sortOrder: sortOrder ?? this.sortOrder,
      colorHex: colorHex ?? this.colorHex,
      presetId: presetId ?? this.presetId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (typeCombinations.present) {
      map['type_combinations'] = Variable<int>(typeCombinations.value);
    }
    if (onConditions.present) {
      map['on_conditions'] = Variable<int>(onConditions.value);
    }
    if (operator.present) {
      map['operator'] = Variable<int>(operator.value);
    }
    if (dayFlags.present) {
      map['day_flags'] = Variable<int>(dayFlags.value);
    }
    if (blockNotifications.present) {
      map['block_notifications'] = Variable<bool>(blockNotifications.value);
    }
    if (blockLaunch.present) {
      map['block_launch'] = Variable<bool>(blockLaunch.value);
    }
    if (addNewApplications.present) {
      map['add_new_applications'] = Variable<bool>(addNewApplications.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (isLocked.present) {
      map['is_locked'] = Variable<bool>(isLocked.value);
    }
    if (lastStartTime.present) {
      map['last_start_time'] = Variable<int>(lastStartTime.value);
    }
    if (onUntil.present) {
      map['on_until'] = Variable<int>(onUntil.value);
    }
    if (lockedUntil.present) {
      map['locked_until'] = Variable<int>(lockedUntil.value);
    }
    if (lockAt.present) {
      map['lock_at'] = Variable<int>(lockAt.value);
    }
    if (pausedUntil.present) {
      map['paused_until'] = Variable<int>(pausedUntil.value);
    }
    if (blockingMode.present) {
      map['blocking_mode'] = Variable<int>(blockingMode.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (blockUnsupportedBrowsers.present) {
      map['block_unsupported_browsers'] = Variable<bool>(
        blockUnsupportedBrowsers.value,
      );
    }
    if (blockAdultContent.present) {
      map['block_adult_content'] = Variable<bool>(blockAdultContent.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (presetId.present) {
      map['preset_id'] = Variable<int>(presetId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('typeCombinations: $typeCombinations, ')
          ..write('onConditions: $onConditions, ')
          ..write('operator: $operator, ')
          ..write('dayFlags: $dayFlags, ')
          ..write('blockNotifications: $blockNotifications, ')
          ..write('blockLaunch: $blockLaunch, ')
          ..write('addNewApplications: $addNewApplications, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('isLocked: $isLocked, ')
          ..write('lastStartTime: $lastStartTime, ')
          ..write('onUntil: $onUntil, ')
          ..write('lockedUntil: $lockedUntil, ')
          ..write('lockAt: $lockAt, ')
          ..write('pausedUntil: $pausedUntil, ')
          ..write('blockingMode: $blockingMode, ')
          ..write('emoji: $emoji, ')
          ..write('blockUnsupportedBrowsers: $blockUnsupportedBrowsers, ')
          ..write('blockAdultContent: $blockAdultContent, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('colorHex: $colorHex, ')
          ..write('presetId: $presetId')
          ..write(')'))
        .toString();
  }
}

class $ApplicationsTable extends Applications
    with TableInfo<$ApplicationsTable, Application> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ApplicationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _packageNameMeta = const VerificationMeta(
    'packageName',
  );
  @override
  late final GeneratedColumn<String> packageName = GeneratedColumn<String>(
    'package_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelForSearchMeta = const VerificationMeta(
    'labelForSearch',
  );
  @override
  late final GeneratedColumn<String> labelForSearch = GeneratedColumn<String>(
    'label_for_search',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isUninstalledMeta = const VerificationMeta(
    'isUninstalled',
  );
  @override
  late final GeneratedColumn<bool> isUninstalled = GeneratedColumn<bool>(
    'is_uninstalled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_uninstalled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    packageName,
    label,
    labelForSearch,
    isUninstalled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'applications';
  @override
  VerificationContext validateIntegrity(
    Insertable<Application> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('package_name')) {
      context.handle(
        _packageNameMeta,
        packageName.isAcceptableOrUnknown(
          data['package_name']!,
          _packageNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_packageNameMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('label_for_search')) {
      context.handle(
        _labelForSearchMeta,
        labelForSearch.isAcceptableOrUnknown(
          data['label_for_search']!,
          _labelForSearchMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_labelForSearchMeta);
    }
    if (data.containsKey('is_uninstalled')) {
      context.handle(
        _isUninstalledMeta,
        isUninstalled.isAcceptableOrUnknown(
          data['is_uninstalled']!,
          _isUninstalledMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {packageName};
  @override
  Application map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Application(
      packageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_name'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      labelForSearch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label_for_search'],
      )!,
      isUninstalled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_uninstalled'],
      )!,
    );
  }

  @override
  $ApplicationsTable createAlias(String alias) {
    return $ApplicationsTable(attachedDatabase, alias);
  }
}

class Application extends DataClass implements Insertable<Application> {
  final String packageName;
  final String label;
  final String labelForSearch;
  final bool isUninstalled;
  const Application({
    required this.packageName,
    required this.label,
    required this.labelForSearch,
    required this.isUninstalled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['package_name'] = Variable<String>(packageName);
    map['label'] = Variable<String>(label);
    map['label_for_search'] = Variable<String>(labelForSearch);
    map['is_uninstalled'] = Variable<bool>(isUninstalled);
    return map;
  }

  ApplicationsCompanion toCompanion(bool nullToAbsent) {
    return ApplicationsCompanion(
      packageName: Value(packageName),
      label: Value(label),
      labelForSearch: Value(labelForSearch),
      isUninstalled: Value(isUninstalled),
    );
  }

  factory Application.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Application(
      packageName: serializer.fromJson<String>(json['packageName']),
      label: serializer.fromJson<String>(json['label']),
      labelForSearch: serializer.fromJson<String>(json['labelForSearch']),
      isUninstalled: serializer.fromJson<bool>(json['isUninstalled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'packageName': serializer.toJson<String>(packageName),
      'label': serializer.toJson<String>(label),
      'labelForSearch': serializer.toJson<String>(labelForSearch),
      'isUninstalled': serializer.toJson<bool>(isUninstalled),
    };
  }

  Application copyWith({
    String? packageName,
    String? label,
    String? labelForSearch,
    bool? isUninstalled,
  }) => Application(
    packageName: packageName ?? this.packageName,
    label: label ?? this.label,
    labelForSearch: labelForSearch ?? this.labelForSearch,
    isUninstalled: isUninstalled ?? this.isUninstalled,
  );
  Application copyWithCompanion(ApplicationsCompanion data) {
    return Application(
      packageName: data.packageName.present
          ? data.packageName.value
          : this.packageName,
      label: data.label.present ? data.label.value : this.label,
      labelForSearch: data.labelForSearch.present
          ? data.labelForSearch.value
          : this.labelForSearch,
      isUninstalled: data.isUninstalled.present
          ? data.isUninstalled.value
          : this.isUninstalled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Application(')
          ..write('packageName: $packageName, ')
          ..write('label: $label, ')
          ..write('labelForSearch: $labelForSearch, ')
          ..write('isUninstalled: $isUninstalled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(packageName, label, labelForSearch, isUninstalled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Application &&
          other.packageName == this.packageName &&
          other.label == this.label &&
          other.labelForSearch == this.labelForSearch &&
          other.isUninstalled == this.isUninstalled);
}

class ApplicationsCompanion extends UpdateCompanion<Application> {
  final Value<String> packageName;
  final Value<String> label;
  final Value<String> labelForSearch;
  final Value<bool> isUninstalled;
  final Value<int> rowid;
  const ApplicationsCompanion({
    this.packageName = const Value.absent(),
    this.label = const Value.absent(),
    this.labelForSearch = const Value.absent(),
    this.isUninstalled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ApplicationsCompanion.insert({
    required String packageName,
    required String label,
    required String labelForSearch,
    this.isUninstalled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : packageName = Value(packageName),
       label = Value(label),
       labelForSearch = Value(labelForSearch);
  static Insertable<Application> custom({
    Expression<String>? packageName,
    Expression<String>? label,
    Expression<String>? labelForSearch,
    Expression<bool>? isUninstalled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (packageName != null) 'package_name': packageName,
      if (label != null) 'label': label,
      if (labelForSearch != null) 'label_for_search': labelForSearch,
      if (isUninstalled != null) 'is_uninstalled': isUninstalled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ApplicationsCompanion copyWith({
    Value<String>? packageName,
    Value<String>? label,
    Value<String>? labelForSearch,
    Value<bool>? isUninstalled,
    Value<int>? rowid,
  }) {
    return ApplicationsCompanion(
      packageName: packageName ?? this.packageName,
      label: label ?? this.label,
      labelForSearch: labelForSearch ?? this.labelForSearch,
      isUninstalled: isUninstalled ?? this.isUninstalled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (packageName.present) {
      map['package_name'] = Variable<String>(packageName.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (labelForSearch.present) {
      map['label_for_search'] = Variable<String>(labelForSearch.value);
    }
    if (isUninstalled.present) {
      map['is_uninstalled'] = Variable<bool>(isUninstalled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ApplicationsCompanion(')
          ..write('packageName: $packageName, ')
          ..write('label: $label, ')
          ..write('labelForSearch: $labelForSearch, ')
          ..write('isUninstalled: $isUninstalled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppProfileRelationsTable extends AppProfileRelations
    with TableInfo<$AppProfileRelationsTable, AppProfileRelation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppProfileRelationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _packageNameMeta = const VerificationMeta(
    'packageName',
  );
  @override
  late final GeneratedColumn<String> packageName = GeneratedColumn<String>(
    'package_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _overlayConfigJsonMeta = const VerificationMeta(
    'overlayConfigJson',
  );
  @override
  late final GeneratedColumn<String> overlayConfigJson =
      GeneratedColumn<String>(
        'overlay_config_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _blockedSectionsJsonMeta =
      const VerificationMeta('blockedSectionsJson');
  @override
  late final GeneratedColumn<String> blockedSectionsJson =
      GeneratedColumn<String>(
        'blocked_sections_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    packageName,
    isEnabled,
    overlayConfigJson,
    blockedSectionsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_profile_relations';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppProfileRelation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('package_name')) {
      context.handle(
        _packageNameMeta,
        packageName.isAcceptableOrUnknown(
          data['package_name']!,
          _packageNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_packageNameMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('overlay_config_json')) {
      context.handle(
        _overlayConfigJsonMeta,
        overlayConfigJson.isAcceptableOrUnknown(
          data['overlay_config_json']!,
          _overlayConfigJsonMeta,
        ),
      );
    }
    if (data.containsKey('blocked_sections_json')) {
      context.handle(
        _blockedSectionsJsonMeta,
        blockedSectionsJson.isAcceptableOrUnknown(
          data['blocked_sections_json']!,
          _blockedSectionsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppProfileRelation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppProfileRelation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      packageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_name'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      overlayConfigJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overlay_config_json'],
      ),
      blockedSectionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blocked_sections_json'],
      ),
    );
  }

  @override
  $AppProfileRelationsTable createAlias(String alias) {
    return $AppProfileRelationsTable(attachedDatabase, alias);
  }
}

class AppProfileRelation extends DataClass
    implements Insertable<AppProfileRelation> {
  final int id;
  final int profileId;
  final String packageName;
  final bool isEnabled;
  final String? overlayConfigJson;
  final String? blockedSectionsJson;
  const AppProfileRelation({
    required this.id,
    required this.profileId,
    required this.packageName,
    required this.isEnabled,
    this.overlayConfigJson,
    this.blockedSectionsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['package_name'] = Variable<String>(packageName);
    map['is_enabled'] = Variable<bool>(isEnabled);
    if (!nullToAbsent || overlayConfigJson != null) {
      map['overlay_config_json'] = Variable<String>(overlayConfigJson);
    }
    if (!nullToAbsent || blockedSectionsJson != null) {
      map['blocked_sections_json'] = Variable<String>(blockedSectionsJson);
    }
    return map;
  }

  AppProfileRelationsCompanion toCompanion(bool nullToAbsent) {
    return AppProfileRelationsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      packageName: Value(packageName),
      isEnabled: Value(isEnabled),
      overlayConfigJson: overlayConfigJson == null && nullToAbsent
          ? const Value.absent()
          : Value(overlayConfigJson),
      blockedSectionsJson: blockedSectionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(blockedSectionsJson),
    );
  }

  factory AppProfileRelation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppProfileRelation(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      packageName: serializer.fromJson<String>(json['packageName']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      overlayConfigJson: serializer.fromJson<String?>(
        json['overlayConfigJson'],
      ),
      blockedSectionsJson: serializer.fromJson<String?>(
        json['blockedSectionsJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'packageName': serializer.toJson<String>(packageName),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'overlayConfigJson': serializer.toJson<String?>(overlayConfigJson),
      'blockedSectionsJson': serializer.toJson<String?>(blockedSectionsJson),
    };
  }

  AppProfileRelation copyWith({
    int? id,
    int? profileId,
    String? packageName,
    bool? isEnabled,
    Value<String?> overlayConfigJson = const Value.absent(),
    Value<String?> blockedSectionsJson = const Value.absent(),
  }) => AppProfileRelation(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    packageName: packageName ?? this.packageName,
    isEnabled: isEnabled ?? this.isEnabled,
    overlayConfigJson: overlayConfigJson.present
        ? overlayConfigJson.value
        : this.overlayConfigJson,
    blockedSectionsJson: blockedSectionsJson.present
        ? blockedSectionsJson.value
        : this.blockedSectionsJson,
  );
  AppProfileRelation copyWithCompanion(AppProfileRelationsCompanion data) {
    return AppProfileRelation(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      packageName: data.packageName.present
          ? data.packageName.value
          : this.packageName,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      overlayConfigJson: data.overlayConfigJson.present
          ? data.overlayConfigJson.value
          : this.overlayConfigJson,
      blockedSectionsJson: data.blockedSectionsJson.present
          ? data.blockedSectionsJson.value
          : this.blockedSectionsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppProfileRelation(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('packageName: $packageName, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('overlayConfigJson: $overlayConfigJson, ')
          ..write('blockedSectionsJson: $blockedSectionsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    packageName,
    isEnabled,
    overlayConfigJson,
    blockedSectionsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppProfileRelation &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.packageName == this.packageName &&
          other.isEnabled == this.isEnabled &&
          other.overlayConfigJson == this.overlayConfigJson &&
          other.blockedSectionsJson == this.blockedSectionsJson);
}

class AppProfileRelationsCompanion extends UpdateCompanion<AppProfileRelation> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> packageName;
  final Value<bool> isEnabled;
  final Value<String?> overlayConfigJson;
  final Value<String?> blockedSectionsJson;
  const AppProfileRelationsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.packageName = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.overlayConfigJson = const Value.absent(),
    this.blockedSectionsJson = const Value.absent(),
  });
  AppProfileRelationsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String packageName,
    this.isEnabled = const Value.absent(),
    this.overlayConfigJson = const Value.absent(),
    this.blockedSectionsJson = const Value.absent(),
  }) : profileId = Value(profileId),
       packageName = Value(packageName);
  static Insertable<AppProfileRelation> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? packageName,
    Expression<bool>? isEnabled,
    Expression<String>? overlayConfigJson,
    Expression<String>? blockedSectionsJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (packageName != null) 'package_name': packageName,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (overlayConfigJson != null) 'overlay_config_json': overlayConfigJson,
      if (blockedSectionsJson != null)
        'blocked_sections_json': blockedSectionsJson,
    });
  }

  AppProfileRelationsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? packageName,
    Value<bool>? isEnabled,
    Value<String?>? overlayConfigJson,
    Value<String?>? blockedSectionsJson,
  }) {
    return AppProfileRelationsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      packageName: packageName ?? this.packageName,
      isEnabled: isEnabled ?? this.isEnabled,
      overlayConfigJson: overlayConfigJson ?? this.overlayConfigJson,
      blockedSectionsJson: blockedSectionsJson ?? this.blockedSectionsJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (packageName.present) {
      map['package_name'] = Variable<String>(packageName.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (overlayConfigJson.present) {
      map['overlay_config_json'] = Variable<String>(overlayConfigJson.value);
    }
    if (blockedSectionsJson.present) {
      map['blocked_sections_json'] = Variable<String>(
        blockedSectionsJson.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppProfileRelationsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('packageName: $packageName, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('overlayConfigJson: $overlayConfigJson, ')
          ..write('blockedSectionsJson: $blockedSectionsJson')
          ..write(')'))
        .toString();
  }
}

class $WebsiteRulesTable extends WebsiteRules
    with TableInfo<$WebsiteRulesTable, WebsiteRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WebsiteRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blockingTypeMeta = const VerificationMeta(
    'blockingType',
  );
  @override
  late final GeneratedColumn<int> blockingType = GeneratedColumn<int>(
    'blocking_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isAnywhereInUrlMeta = const VerificationMeta(
    'isAnywhereInUrl',
  );
  @override
  late final GeneratedColumn<bool> isAnywhereInUrl = GeneratedColumn<bool>(
    'is_anywhere_in_url',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_anywhere_in_url" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    name,
    blockingType,
    isAnywhereInUrl,
    isEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'website_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<WebsiteRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('blocking_type')) {
      context.handle(
        _blockingTypeMeta,
        blockingType.isAcceptableOrUnknown(
          data['blocking_type']!,
          _blockingTypeMeta,
        ),
      );
    }
    if (data.containsKey('is_anywhere_in_url')) {
      context.handle(
        _isAnywhereInUrlMeta,
        isAnywhereInUrl.isAcceptableOrUnknown(
          data['is_anywhere_in_url']!,
          _isAnywhereInUrlMeta,
        ),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WebsiteRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WebsiteRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      blockingType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blocking_type'],
      )!,
      isAnywhereInUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_anywhere_in_url'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
    );
  }

  @override
  $WebsiteRulesTable createAlias(String alias) {
    return $WebsiteRulesTable(attachedDatabase, alias);
  }
}

class WebsiteRule extends DataClass implements Insertable<WebsiteRule> {
  final int id;
  final int profileId;
  final String name;
  final int blockingType;
  final bool isAnywhereInUrl;
  final bool isEnabled;
  const WebsiteRule({
    required this.id,
    required this.profileId,
    required this.name,
    required this.blockingType,
    required this.isAnywhereInUrl,
    required this.isEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['name'] = Variable<String>(name);
    map['blocking_type'] = Variable<int>(blockingType);
    map['is_anywhere_in_url'] = Variable<bool>(isAnywhereInUrl);
    map['is_enabled'] = Variable<bool>(isEnabled);
    return map;
  }

  WebsiteRulesCompanion toCompanion(bool nullToAbsent) {
    return WebsiteRulesCompanion(
      id: Value(id),
      profileId: Value(profileId),
      name: Value(name),
      blockingType: Value(blockingType),
      isAnywhereInUrl: Value(isAnywhereInUrl),
      isEnabled: Value(isEnabled),
    );
  }

  factory WebsiteRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WebsiteRule(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      name: serializer.fromJson<String>(json['name']),
      blockingType: serializer.fromJson<int>(json['blockingType']),
      isAnywhereInUrl: serializer.fromJson<bool>(json['isAnywhereInUrl']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'name': serializer.toJson<String>(name),
      'blockingType': serializer.toJson<int>(blockingType),
      'isAnywhereInUrl': serializer.toJson<bool>(isAnywhereInUrl),
      'isEnabled': serializer.toJson<bool>(isEnabled),
    };
  }

  WebsiteRule copyWith({
    int? id,
    int? profileId,
    String? name,
    int? blockingType,
    bool? isAnywhereInUrl,
    bool? isEnabled,
  }) => WebsiteRule(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    name: name ?? this.name,
    blockingType: blockingType ?? this.blockingType,
    isAnywhereInUrl: isAnywhereInUrl ?? this.isAnywhereInUrl,
    isEnabled: isEnabled ?? this.isEnabled,
  );
  WebsiteRule copyWithCompanion(WebsiteRulesCompanion data) {
    return WebsiteRule(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      name: data.name.present ? data.name.value : this.name,
      blockingType: data.blockingType.present
          ? data.blockingType.value
          : this.blockingType,
      isAnywhereInUrl: data.isAnywhereInUrl.present
          ? data.isAnywhereInUrl.value
          : this.isAnywhereInUrl,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WebsiteRule(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('name: $name, ')
          ..write('blockingType: $blockingType, ')
          ..write('isAnywhereInUrl: $isAnywhereInUrl, ')
          ..write('isEnabled: $isEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    name,
    blockingType,
    isAnywhereInUrl,
    isEnabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WebsiteRule &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.name == this.name &&
          other.blockingType == this.blockingType &&
          other.isAnywhereInUrl == this.isAnywhereInUrl &&
          other.isEnabled == this.isEnabled);
}

class WebsiteRulesCompanion extends UpdateCompanion<WebsiteRule> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> name;
  final Value<int> blockingType;
  final Value<bool> isAnywhereInUrl;
  final Value<bool> isEnabled;
  const WebsiteRulesCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.name = const Value.absent(),
    this.blockingType = const Value.absent(),
    this.isAnywhereInUrl = const Value.absent(),
    this.isEnabled = const Value.absent(),
  });
  WebsiteRulesCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String name,
    this.blockingType = const Value.absent(),
    this.isAnywhereInUrl = const Value.absent(),
    this.isEnabled = const Value.absent(),
  }) : profileId = Value(profileId),
       name = Value(name);
  static Insertable<WebsiteRule> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? name,
    Expression<int>? blockingType,
    Expression<bool>? isAnywhereInUrl,
    Expression<bool>? isEnabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (name != null) 'name': name,
      if (blockingType != null) 'blocking_type': blockingType,
      if (isAnywhereInUrl != null) 'is_anywhere_in_url': isAnywhereInUrl,
      if (isEnabled != null) 'is_enabled': isEnabled,
    });
  }

  WebsiteRulesCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? name,
    Value<int>? blockingType,
    Value<bool>? isAnywhereInUrl,
    Value<bool>? isEnabled,
  }) {
    return WebsiteRulesCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      blockingType: blockingType ?? this.blockingType,
      isAnywhereInUrl: isAnywhereInUrl ?? this.isAnywhereInUrl,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (blockingType.present) {
      map['blocking_type'] = Variable<int>(blockingType.value);
    }
    if (isAnywhereInUrl.present) {
      map['is_anywhere_in_url'] = Variable<bool>(isAnywhereInUrl.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WebsiteRulesCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('name: $name, ')
          ..write('blockingType: $blockingType, ')
          ..write('isAnywhereInUrl: $isAnywhereInUrl, ')
          ..write('isEnabled: $isEnabled')
          ..write(')'))
        .toString();
  }
}

class $IntervalsTable extends Intervals
    with TableInfo<$IntervalsTable, Interval> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IntervalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _fromMinutesMeta = const VerificationMeta(
    'fromMinutes',
  );
  @override
  late final GeneratedColumn<int> fromMinutes = GeneratedColumn<int>(
    'from_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toMinutesMeta = const VerificationMeta(
    'toMinutes',
  );
  @override
  late final GeneratedColumn<int> toMinutes = GeneratedColumn<int>(
    'to_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isAllDayAutoMeta = const VerificationMeta(
    'isAllDayAuto',
  );
  @override
  late final GeneratedColumn<bool> isAllDayAuto = GeneratedColumn<bool>(
    'is_all_day_auto',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_all_day_auto" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    fromMinutes,
    toMinutes,
    parentId,
    isAllDayAuto,
    isEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'intervals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Interval> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('from_minutes')) {
      context.handle(
        _fromMinutesMeta,
        fromMinutes.isAcceptableOrUnknown(
          data['from_minutes']!,
          _fromMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromMinutesMeta);
    }
    if (data.containsKey('to_minutes')) {
      context.handle(
        _toMinutesMeta,
        toMinutes.isAcceptableOrUnknown(data['to_minutes']!, _toMinutesMeta),
      );
    } else if (isInserting) {
      context.missing(_toMinutesMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('is_all_day_auto')) {
      context.handle(
        _isAllDayAutoMeta,
        isAllDayAuto.isAcceptableOrUnknown(
          data['is_all_day_auto']!,
          _isAllDayAutoMeta,
        ),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Interval map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Interval(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      fromMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}from_minutes'],
      )!,
      toMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}to_minutes'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_id'],
      ),
      isAllDayAuto: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_all_day_auto'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
    );
  }

  @override
  $IntervalsTable createAlias(String alias) {
    return $IntervalsTable(attachedDatabase, alias);
  }
}

class Interval extends DataClass implements Insertable<Interval> {
  final int id;
  final int profileId;
  final int fromMinutes;
  final int toMinutes;
  final int? parentId;
  final bool isAllDayAuto;
  final bool isEnabled;
  const Interval({
    required this.id,
    required this.profileId,
    required this.fromMinutes,
    required this.toMinutes,
    this.parentId,
    required this.isAllDayAuto,
    required this.isEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['from_minutes'] = Variable<int>(fromMinutes);
    map['to_minutes'] = Variable<int>(toMinutes);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['is_all_day_auto'] = Variable<bool>(isAllDayAuto);
    map['is_enabled'] = Variable<bool>(isEnabled);
    return map;
  }

  IntervalsCompanion toCompanion(bool nullToAbsent) {
    return IntervalsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      fromMinutes: Value(fromMinutes),
      toMinutes: Value(toMinutes),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      isAllDayAuto: Value(isAllDayAuto),
      isEnabled: Value(isEnabled),
    );
  }

  factory Interval.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Interval(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      fromMinutes: serializer.fromJson<int>(json['fromMinutes']),
      toMinutes: serializer.fromJson<int>(json['toMinutes']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      isAllDayAuto: serializer.fromJson<bool>(json['isAllDayAuto']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'fromMinutes': serializer.toJson<int>(fromMinutes),
      'toMinutes': serializer.toJson<int>(toMinutes),
      'parentId': serializer.toJson<int?>(parentId),
      'isAllDayAuto': serializer.toJson<bool>(isAllDayAuto),
      'isEnabled': serializer.toJson<bool>(isEnabled),
    };
  }

  Interval copyWith({
    int? id,
    int? profileId,
    int? fromMinutes,
    int? toMinutes,
    Value<int?> parentId = const Value.absent(),
    bool? isAllDayAuto,
    bool? isEnabled,
  }) => Interval(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    fromMinutes: fromMinutes ?? this.fromMinutes,
    toMinutes: toMinutes ?? this.toMinutes,
    parentId: parentId.present ? parentId.value : this.parentId,
    isAllDayAuto: isAllDayAuto ?? this.isAllDayAuto,
    isEnabled: isEnabled ?? this.isEnabled,
  );
  Interval copyWithCompanion(IntervalsCompanion data) {
    return Interval(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      fromMinutes: data.fromMinutes.present
          ? data.fromMinutes.value
          : this.fromMinutes,
      toMinutes: data.toMinutes.present ? data.toMinutes.value : this.toMinutes,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      isAllDayAuto: data.isAllDayAuto.present
          ? data.isAllDayAuto.value
          : this.isAllDayAuto,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Interval(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('fromMinutes: $fromMinutes, ')
          ..write('toMinutes: $toMinutes, ')
          ..write('parentId: $parentId, ')
          ..write('isAllDayAuto: $isAllDayAuto, ')
          ..write('isEnabled: $isEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    fromMinutes,
    toMinutes,
    parentId,
    isAllDayAuto,
    isEnabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Interval &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.fromMinutes == this.fromMinutes &&
          other.toMinutes == this.toMinutes &&
          other.parentId == this.parentId &&
          other.isAllDayAuto == this.isAllDayAuto &&
          other.isEnabled == this.isEnabled);
}

class IntervalsCompanion extends UpdateCompanion<Interval> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<int> fromMinutes;
  final Value<int> toMinutes;
  final Value<int?> parentId;
  final Value<bool> isAllDayAuto;
  final Value<bool> isEnabled;
  const IntervalsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.fromMinutes = const Value.absent(),
    this.toMinutes = const Value.absent(),
    this.parentId = const Value.absent(),
    this.isAllDayAuto = const Value.absent(),
    this.isEnabled = const Value.absent(),
  });
  IntervalsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required int fromMinutes,
    required int toMinutes,
    this.parentId = const Value.absent(),
    this.isAllDayAuto = const Value.absent(),
    this.isEnabled = const Value.absent(),
  }) : profileId = Value(profileId),
       fromMinutes = Value(fromMinutes),
       toMinutes = Value(toMinutes);
  static Insertable<Interval> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<int>? fromMinutes,
    Expression<int>? toMinutes,
    Expression<int>? parentId,
    Expression<bool>? isAllDayAuto,
    Expression<bool>? isEnabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (fromMinutes != null) 'from_minutes': fromMinutes,
      if (toMinutes != null) 'to_minutes': toMinutes,
      if (parentId != null) 'parent_id': parentId,
      if (isAllDayAuto != null) 'is_all_day_auto': isAllDayAuto,
      if (isEnabled != null) 'is_enabled': isEnabled,
    });
  }

  IntervalsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<int>? fromMinutes,
    Value<int>? toMinutes,
    Value<int?>? parentId,
    Value<bool>? isAllDayAuto,
    Value<bool>? isEnabled,
  }) {
    return IntervalsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      fromMinutes: fromMinutes ?? this.fromMinutes,
      toMinutes: toMinutes ?? this.toMinutes,
      parentId: parentId ?? this.parentId,
      isAllDayAuto: isAllDayAuto ?? this.isAllDayAuto,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (fromMinutes.present) {
      map['from_minutes'] = Variable<int>(fromMinutes.value);
    }
    if (toMinutes.present) {
      map['to_minutes'] = Variable<int>(toMinutes.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (isAllDayAuto.present) {
      map['is_all_day_auto'] = Variable<bool>(isAllDayAuto.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IntervalsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('fromMinutes: $fromMinutes, ')
          ..write('toMinutes: $toMinutes, ')
          ..write('parentId: $parentId, ')
          ..write('isAllDayAuto: $isAllDayAuto, ')
          ..write('isEnabled: $isEnabled')
          ..write(')'))
        .toString();
  }
}

class $UsageLimitsTable extends UsageLimits
    with TableInfo<$UsageLimitsTable, UsageLimit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageLimitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _periodTypeMeta = const VerificationMeta(
    'periodType',
  );
  @override
  late final GeneratedColumn<int> periodType = GeneratedColumn<int>(
    'period_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _limitTypeMeta = const VerificationMeta(
    'limitType',
  );
  @override
  late final GeneratedColumn<int> limitType = GeneratedColumn<int>(
    'limit_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastResetTimeMeta = const VerificationMeta(
    'lastResetTime',
  );
  @override
  late final GeneratedColumn<int> lastResetTime = GeneratedColumn<int>(
    'last_reset_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _allowedCountMeta = const VerificationMeta(
    'allowedCount',
  );
  @override
  late final GeneratedColumn<int> allowedCount = GeneratedColumn<int>(
    'allowed_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _usedCountMeta = const VerificationMeta(
    'usedCount',
  );
  @override
  late final GeneratedColumn<int> usedCount = GeneratedColumn<int>(
    'used_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _originalAllowedCountMeta =
      const VerificationMeta('originalAllowedCount');
  @override
  late final GeneratedColumn<int> originalAllowedCount = GeneratedColumn<int>(
    'original_allowed_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    periodType,
    limitType,
    lastResetTime,
    allowedCount,
    usedCount,
    originalAllowedCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_limits';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageLimit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('period_type')) {
      context.handle(
        _periodTypeMeta,
        periodType.isAcceptableOrUnknown(data['period_type']!, _periodTypeMeta),
      );
    }
    if (data.containsKey('limit_type')) {
      context.handle(
        _limitTypeMeta,
        limitType.isAcceptableOrUnknown(data['limit_type']!, _limitTypeMeta),
      );
    }
    if (data.containsKey('last_reset_time')) {
      context.handle(
        _lastResetTimeMeta,
        lastResetTime.isAcceptableOrUnknown(
          data['last_reset_time']!,
          _lastResetTimeMeta,
        ),
      );
    }
    if (data.containsKey('allowed_count')) {
      context.handle(
        _allowedCountMeta,
        allowedCount.isAcceptableOrUnknown(
          data['allowed_count']!,
          _allowedCountMeta,
        ),
      );
    }
    if (data.containsKey('used_count')) {
      context.handle(
        _usedCountMeta,
        usedCount.isAcceptableOrUnknown(data['used_count']!, _usedCountMeta),
      );
    }
    if (data.containsKey('original_allowed_count')) {
      context.handle(
        _originalAllowedCountMeta,
        originalAllowedCount.isAcceptableOrUnknown(
          data['original_allowed_count']!,
          _originalAllowedCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UsageLimit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageLimit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      periodType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}period_type'],
      )!,
      limitType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}limit_type'],
      )!,
      lastResetTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_reset_time'],
      )!,
      allowedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}allowed_count'],
      )!,
      usedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}used_count'],
      )!,
      originalAllowedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}original_allowed_count'],
      )!,
    );
  }

  @override
  $UsageLimitsTable createAlias(String alias) {
    return $UsageLimitsTable(attachedDatabase, alias);
  }
}

class UsageLimit extends DataClass implements Insertable<UsageLimit> {
  final int id;
  final int profileId;
  final int periodType;
  final int limitType;
  final int lastResetTime;
  final int allowedCount;
  final int usedCount;
  final int originalAllowedCount;
  const UsageLimit({
    required this.id,
    required this.profileId,
    required this.periodType,
    required this.limitType,
    required this.lastResetTime,
    required this.allowedCount,
    required this.usedCount,
    required this.originalAllowedCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['period_type'] = Variable<int>(periodType);
    map['limit_type'] = Variable<int>(limitType);
    map['last_reset_time'] = Variable<int>(lastResetTime);
    map['allowed_count'] = Variable<int>(allowedCount);
    map['used_count'] = Variable<int>(usedCount);
    map['original_allowed_count'] = Variable<int>(originalAllowedCount);
    return map;
  }

  UsageLimitsCompanion toCompanion(bool nullToAbsent) {
    return UsageLimitsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      periodType: Value(periodType),
      limitType: Value(limitType),
      lastResetTime: Value(lastResetTime),
      allowedCount: Value(allowedCount),
      usedCount: Value(usedCount),
      originalAllowedCount: Value(originalAllowedCount),
    );
  }

  factory UsageLimit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageLimit(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      periodType: serializer.fromJson<int>(json['periodType']),
      limitType: serializer.fromJson<int>(json['limitType']),
      lastResetTime: serializer.fromJson<int>(json['lastResetTime']),
      allowedCount: serializer.fromJson<int>(json['allowedCount']),
      usedCount: serializer.fromJson<int>(json['usedCount']),
      originalAllowedCount: serializer.fromJson<int>(
        json['originalAllowedCount'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'periodType': serializer.toJson<int>(periodType),
      'limitType': serializer.toJson<int>(limitType),
      'lastResetTime': serializer.toJson<int>(lastResetTime),
      'allowedCount': serializer.toJson<int>(allowedCount),
      'usedCount': serializer.toJson<int>(usedCount),
      'originalAllowedCount': serializer.toJson<int>(originalAllowedCount),
    };
  }

  UsageLimit copyWith({
    int? id,
    int? profileId,
    int? periodType,
    int? limitType,
    int? lastResetTime,
    int? allowedCount,
    int? usedCount,
    int? originalAllowedCount,
  }) => UsageLimit(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    periodType: periodType ?? this.periodType,
    limitType: limitType ?? this.limitType,
    lastResetTime: lastResetTime ?? this.lastResetTime,
    allowedCount: allowedCount ?? this.allowedCount,
    usedCount: usedCount ?? this.usedCount,
    originalAllowedCount: originalAllowedCount ?? this.originalAllowedCount,
  );
  UsageLimit copyWithCompanion(UsageLimitsCompanion data) {
    return UsageLimit(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      periodType: data.periodType.present
          ? data.periodType.value
          : this.periodType,
      limitType: data.limitType.present ? data.limitType.value : this.limitType,
      lastResetTime: data.lastResetTime.present
          ? data.lastResetTime.value
          : this.lastResetTime,
      allowedCount: data.allowedCount.present
          ? data.allowedCount.value
          : this.allowedCount,
      usedCount: data.usedCount.present ? data.usedCount.value : this.usedCount,
      originalAllowedCount: data.originalAllowedCount.present
          ? data.originalAllowedCount.value
          : this.originalAllowedCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageLimit(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('periodType: $periodType, ')
          ..write('limitType: $limitType, ')
          ..write('lastResetTime: $lastResetTime, ')
          ..write('allowedCount: $allowedCount, ')
          ..write('usedCount: $usedCount, ')
          ..write('originalAllowedCount: $originalAllowedCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    periodType,
    limitType,
    lastResetTime,
    allowedCount,
    usedCount,
    originalAllowedCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageLimit &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.periodType == this.periodType &&
          other.limitType == this.limitType &&
          other.lastResetTime == this.lastResetTime &&
          other.allowedCount == this.allowedCount &&
          other.usedCount == this.usedCount &&
          other.originalAllowedCount == this.originalAllowedCount);
}

class UsageLimitsCompanion extends UpdateCompanion<UsageLimit> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<int> periodType;
  final Value<int> limitType;
  final Value<int> lastResetTime;
  final Value<int> allowedCount;
  final Value<int> usedCount;
  final Value<int> originalAllowedCount;
  const UsageLimitsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.periodType = const Value.absent(),
    this.limitType = const Value.absent(),
    this.lastResetTime = const Value.absent(),
    this.allowedCount = const Value.absent(),
    this.usedCount = const Value.absent(),
    this.originalAllowedCount = const Value.absent(),
  });
  UsageLimitsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    this.periodType = const Value.absent(),
    this.limitType = const Value.absent(),
    this.lastResetTime = const Value.absent(),
    this.allowedCount = const Value.absent(),
    this.usedCount = const Value.absent(),
    this.originalAllowedCount = const Value.absent(),
  }) : profileId = Value(profileId);
  static Insertable<UsageLimit> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<int>? periodType,
    Expression<int>? limitType,
    Expression<int>? lastResetTime,
    Expression<int>? allowedCount,
    Expression<int>? usedCount,
    Expression<int>? originalAllowedCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (periodType != null) 'period_type': periodType,
      if (limitType != null) 'limit_type': limitType,
      if (lastResetTime != null) 'last_reset_time': lastResetTime,
      if (allowedCount != null) 'allowed_count': allowedCount,
      if (usedCount != null) 'used_count': usedCount,
      if (originalAllowedCount != null)
        'original_allowed_count': originalAllowedCount,
    });
  }

  UsageLimitsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<int>? periodType,
    Value<int>? limitType,
    Value<int>? lastResetTime,
    Value<int>? allowedCount,
    Value<int>? usedCount,
    Value<int>? originalAllowedCount,
  }) {
    return UsageLimitsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      periodType: periodType ?? this.periodType,
      limitType: limitType ?? this.limitType,
      lastResetTime: lastResetTime ?? this.lastResetTime,
      allowedCount: allowedCount ?? this.allowedCount,
      usedCount: usedCount ?? this.usedCount,
      originalAllowedCount: originalAllowedCount ?? this.originalAllowedCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (periodType.present) {
      map['period_type'] = Variable<int>(periodType.value);
    }
    if (limitType.present) {
      map['limit_type'] = Variable<int>(limitType.value);
    }
    if (lastResetTime.present) {
      map['last_reset_time'] = Variable<int>(lastResetTime.value);
    }
    if (allowedCount.present) {
      map['allowed_count'] = Variable<int>(allowedCount.value);
    }
    if (usedCount.present) {
      map['used_count'] = Variable<int>(usedCount.value);
    }
    if (originalAllowedCount.present) {
      map['original_allowed_count'] = Variable<int>(originalAllowedCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageLimitsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('periodType: $periodType, ')
          ..write('limitType: $limitType, ')
          ..write('lastResetTime: $lastResetTime, ')
          ..write('allowedCount: $allowedCount, ')
          ..write('usedCount: $usedCount, ')
          ..write('originalAllowedCount: $originalAllowedCount')
          ..write(')'))
        .toString();
  }
}

class $GeoAddressesTable extends GeoAddresses
    with TableInfo<$GeoAddressesTable, GeoAddressesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GeoAddressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _geofenceIdMeta = const VerificationMeta(
    'geofenceId',
  );
  @override
  late final GeneratedColumn<String> geofenceId = GeneratedColumn<String>(
    'geofence_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _radiusMetersMeta = const VerificationMeta(
    'radiusMeters',
  );
  @override
  late final GeneratedColumn<int> radiusMeters = GeneratedColumn<int>(
    'radius_meters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(200),
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isInvertedMeta = const VerificationMeta(
    'isInverted',
  );
  @override
  late final GeneratedColumn<bool> isInverted = GeneratedColumn<bool>(
    'is_inverted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_inverted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    geofenceId,
    radiusMeters,
    latitude,
    longitude,
    isInverted,
    displayName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'geo_addresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<GeoAddressesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('geofence_id')) {
      context.handle(
        _geofenceIdMeta,
        geofenceId.isAcceptableOrUnknown(data['geofence_id']!, _geofenceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_geofenceIdMeta);
    }
    if (data.containsKey('radius_meters')) {
      context.handle(
        _radiusMetersMeta,
        radiusMeters.isAcceptableOrUnknown(
          data['radius_meters']!,
          _radiusMetersMeta,
        ),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('is_inverted')) {
      context.handle(
        _isInvertedMeta,
        isInverted.isAcceptableOrUnknown(data['is_inverted']!, _isInvertedMeta),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GeoAddressesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GeoAddressesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      geofenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geofence_id'],
      )!,
      radiusMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}radius_meters'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      isInverted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_inverted'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
    );
  }

  @override
  $GeoAddressesTable createAlias(String alias) {
    return $GeoAddressesTable(attachedDatabase, alias);
  }
}

class GeoAddressesData extends DataClass
    implements Insertable<GeoAddressesData> {
  final int id;
  final int profileId;
  final String geofenceId;
  final int radiusMeters;
  final double latitude;
  final double longitude;
  final bool isInverted;
  final String? displayName;
  const GeoAddressesData({
    required this.id,
    required this.profileId,
    required this.geofenceId,
    required this.radiusMeters,
    required this.latitude,
    required this.longitude,
    required this.isInverted,
    this.displayName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['geofence_id'] = Variable<String>(geofenceId);
    map['radius_meters'] = Variable<int>(radiusMeters);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['is_inverted'] = Variable<bool>(isInverted);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    return map;
  }

  GeoAddressesCompanion toCompanion(bool nullToAbsent) {
    return GeoAddressesCompanion(
      id: Value(id),
      profileId: Value(profileId),
      geofenceId: Value(geofenceId),
      radiusMeters: Value(radiusMeters),
      latitude: Value(latitude),
      longitude: Value(longitude),
      isInverted: Value(isInverted),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
    );
  }

  factory GeoAddressesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GeoAddressesData(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      geofenceId: serializer.fromJson<String>(json['geofenceId']),
      radiusMeters: serializer.fromJson<int>(json['radiusMeters']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      isInverted: serializer.fromJson<bool>(json['isInverted']),
      displayName: serializer.fromJson<String?>(json['displayName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'geofenceId': serializer.toJson<String>(geofenceId),
      'radiusMeters': serializer.toJson<int>(radiusMeters),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'isInverted': serializer.toJson<bool>(isInverted),
      'displayName': serializer.toJson<String?>(displayName),
    };
  }

  GeoAddressesData copyWith({
    int? id,
    int? profileId,
    String? geofenceId,
    int? radiusMeters,
    double? latitude,
    double? longitude,
    bool? isInverted,
    Value<String?> displayName = const Value.absent(),
  }) => GeoAddressesData(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    geofenceId: geofenceId ?? this.geofenceId,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    isInverted: isInverted ?? this.isInverted,
    displayName: displayName.present ? displayName.value : this.displayName,
  );
  GeoAddressesData copyWithCompanion(GeoAddressesCompanion data) {
    return GeoAddressesData(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      geofenceId: data.geofenceId.present
          ? data.geofenceId.value
          : this.geofenceId,
      radiusMeters: data.radiusMeters.present
          ? data.radiusMeters.value
          : this.radiusMeters,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      isInverted: data.isInverted.present
          ? data.isInverted.value
          : this.isInverted,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GeoAddressesData(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('geofenceId: $geofenceId, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('isInverted: $isInverted, ')
          ..write('displayName: $displayName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    geofenceId,
    radiusMeters,
    latitude,
    longitude,
    isInverted,
    displayName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GeoAddressesData &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.geofenceId == this.geofenceId &&
          other.radiusMeters == this.radiusMeters &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.isInverted == this.isInverted &&
          other.displayName == this.displayName);
}

class GeoAddressesCompanion extends UpdateCompanion<GeoAddressesData> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> geofenceId;
  final Value<int> radiusMeters;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<bool> isInverted;
  final Value<String?> displayName;
  const GeoAddressesCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.geofenceId = const Value.absent(),
    this.radiusMeters = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.isInverted = const Value.absent(),
    this.displayName = const Value.absent(),
  });
  GeoAddressesCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String geofenceId,
    this.radiusMeters = const Value.absent(),
    required double latitude,
    required double longitude,
    this.isInverted = const Value.absent(),
    this.displayName = const Value.absent(),
  }) : profileId = Value(profileId),
       geofenceId = Value(geofenceId),
       latitude = Value(latitude),
       longitude = Value(longitude);
  static Insertable<GeoAddressesData> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? geofenceId,
    Expression<int>? radiusMeters,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<bool>? isInverted,
    Expression<String>? displayName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (geofenceId != null) 'geofence_id': geofenceId,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (isInverted != null) 'is_inverted': isInverted,
      if (displayName != null) 'display_name': displayName,
    });
  }

  GeoAddressesCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? geofenceId,
    Value<int>? radiusMeters,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<bool>? isInverted,
    Value<String?>? displayName,
  }) {
    return GeoAddressesCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      geofenceId: geofenceId ?? this.geofenceId,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isInverted: isInverted ?? this.isInverted,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (geofenceId.present) {
      map['geofence_id'] = Variable<String>(geofenceId.value);
    }
    if (radiusMeters.present) {
      map['radius_meters'] = Variable<int>(radiusMeters.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (isInverted.present) {
      map['is_inverted'] = Variable<bool>(isInverted.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GeoAddressesCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('geofenceId: $geofenceId, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('isInverted: $isInverted, ')
          ..write('displayName: $displayName')
          ..write(')'))
        .toString();
  }
}

class $WifiNetworksTable extends WifiNetworks
    with TableInfo<$WifiNetworksTable, WifiNetwork> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WifiNetworksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _ssidMeta = const VerificationMeta('ssid');
  @override
  late final GeneratedColumn<String> ssid = GeneratedColumn<String>(
    'ssid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, profileId, ssid];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wifi_networks';
  @override
  VerificationContext validateIntegrity(
    Insertable<WifiNetwork> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('ssid')) {
      context.handle(
        _ssidMeta,
        ssid.isAcceptableOrUnknown(data['ssid']!, _ssidMeta),
      );
    } else if (isInserting) {
      context.missing(_ssidMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WifiNetwork map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WifiNetwork(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      ssid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ssid'],
      )!,
    );
  }

  @override
  $WifiNetworksTable createAlias(String alias) {
    return $WifiNetworksTable(attachedDatabase, alias);
  }
}

class WifiNetwork extends DataClass implements Insertable<WifiNetwork> {
  final int id;
  final int profileId;
  final String ssid;
  const WifiNetwork({
    required this.id,
    required this.profileId,
    required this.ssid,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['ssid'] = Variable<String>(ssid);
    return map;
  }

  WifiNetworksCompanion toCompanion(bool nullToAbsent) {
    return WifiNetworksCompanion(
      id: Value(id),
      profileId: Value(profileId),
      ssid: Value(ssid),
    );
  }

  factory WifiNetwork.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WifiNetwork(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      ssid: serializer.fromJson<String>(json['ssid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'ssid': serializer.toJson<String>(ssid),
    };
  }

  WifiNetwork copyWith({int? id, int? profileId, String? ssid}) => WifiNetwork(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    ssid: ssid ?? this.ssid,
  );
  WifiNetwork copyWithCompanion(WifiNetworksCompanion data) {
    return WifiNetwork(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      ssid: data.ssid.present ? data.ssid.value : this.ssid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WifiNetwork(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('ssid: $ssid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, profileId, ssid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WifiNetwork &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.ssid == this.ssid);
}

class WifiNetworksCompanion extends UpdateCompanion<WifiNetwork> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> ssid;
  const WifiNetworksCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.ssid = const Value.absent(),
  });
  WifiNetworksCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String ssid,
  }) : profileId = Value(profileId),
       ssid = Value(ssid);
  static Insertable<WifiNetwork> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? ssid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (ssid != null) 'ssid': ssid,
    });
  }

  WifiNetworksCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? ssid,
  }) {
    return WifiNetworksCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      ssid: ssid ?? this.ssid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (ssid.present) {
      map['ssid'] = Variable<String>(ssid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WifiNetworksCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('ssid: $ssid')
          ..write(')'))
        .toString();
  }
}

class $BlockSessionsTable extends BlockSessions
    with TableInfo<$BlockSessionsTable, BlockSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlockSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'block_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlockSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BlockSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlockSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $BlockSessionsTable createAlias(String alias) {
    return $BlockSessionsTable(attachedDatabase, alias);
  }
}

class BlockSession extends DataClass implements Insertable<BlockSession> {
  final int id;
  final String name;
  final int timestamp;
  const BlockSession({
    required this.id,
    required this.name,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['timestamp'] = Variable<int>(timestamp);
    return map;
  }

  BlockSessionsCompanion toCompanion(bool nullToAbsent) {
    return BlockSessionsCompanion(
      id: Value(id),
      name: Value(name),
      timestamp: Value(timestamp),
    );
  }

  factory BlockSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlockSession(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'timestamp': serializer.toJson<int>(timestamp),
    };
  }

  BlockSession copyWith({int? id, String? name, int? timestamp}) =>
      BlockSession(
        id: id ?? this.id,
        name: name ?? this.name,
        timestamp: timestamp ?? this.timestamp,
      );
  BlockSession copyWithCompanion(BlockSessionsCompanion data) {
    return BlockSession(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlockSession(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockSession &&
          other.id == this.id &&
          other.name == this.name &&
          other.timestamp == this.timestamp);
}

class BlockSessionsCompanion extends UpdateCompanion<BlockSession> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> timestamp;
  const BlockSessionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  BlockSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int timestamp,
  }) : name = Value(name),
       timestamp = Value(timestamp);
  static Insertable<BlockSession> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  BlockSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? timestamp,
  }) {
    return BlockSessionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlockSessionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $BrowserConfigsTable extends BrowserConfigs
    with TableInfo<$BrowserConfigsTable, BrowserConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BrowserConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _packageNameMeta = const VerificationMeta(
    'packageName',
  );
  @override
  late final GeneratedColumn<String> packageName = GeneratedColumn<String>(
    'package_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viewIdMeta = const VerificationMeta('viewId');
  @override
  late final GeneratedColumn<String> viewId = GeneratedColumn<String>(
    'view_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viewTypeMeta = const VerificationMeta(
    'viewType',
  );
  @override
  late final GeneratedColumn<int> viewType = GeneratedColumn<int>(
    'view_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _clearUrlMeta = const VerificationMeta(
    'clearUrl',
  );
  @override
  late final GeneratedColumn<bool> clearUrl = GeneratedColumn<bool>(
    'clear_url',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("clear_url" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _detectionMethodMeta = const VerificationMeta(
    'detectionMethod',
  );
  @override
  late final GeneratedColumn<String> detectionMethod = GeneratedColumn<String>(
    'detection_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('VIEW_ID'),
  );
  static const VerificationMeta _extractionMethodMeta = const VerificationMeta(
    'extractionMethod',
  );
  @override
  late final GeneratedColumn<String> extractionMethod = GeneratedColumn<String>(
    'extraction_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('TEXT'),
  );
  static const VerificationMeta _clickToOpenViewIdMeta = const VerificationMeta(
    'clickToOpenViewId',
  );
  @override
  late final GeneratedColumn<String> clickToOpenViewId =
      GeneratedColumn<String>(
        'click_to_open_view_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    packageName,
    viewId,
    viewType,
    clearUrl,
    detectionMethod,
    extractionMethod,
    clickToOpenViewId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'browser_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<BrowserConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('package_name')) {
      context.handle(
        _packageNameMeta,
        packageName.isAcceptableOrUnknown(
          data['package_name']!,
          _packageNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_packageNameMeta);
    }
    if (data.containsKey('view_id')) {
      context.handle(
        _viewIdMeta,
        viewId.isAcceptableOrUnknown(data['view_id']!, _viewIdMeta),
      );
    } else if (isInserting) {
      context.missing(_viewIdMeta);
    }
    if (data.containsKey('view_type')) {
      context.handle(
        _viewTypeMeta,
        viewType.isAcceptableOrUnknown(data['view_type']!, _viewTypeMeta),
      );
    }
    if (data.containsKey('clear_url')) {
      context.handle(
        _clearUrlMeta,
        clearUrl.isAcceptableOrUnknown(data['clear_url']!, _clearUrlMeta),
      );
    }
    if (data.containsKey('detection_method')) {
      context.handle(
        _detectionMethodMeta,
        detectionMethod.isAcceptableOrUnknown(
          data['detection_method']!,
          _detectionMethodMeta,
        ),
      );
    }
    if (data.containsKey('extraction_method')) {
      context.handle(
        _extractionMethodMeta,
        extractionMethod.isAcceptableOrUnknown(
          data['extraction_method']!,
          _extractionMethodMeta,
        ),
      );
    }
    if (data.containsKey('click_to_open_view_id')) {
      context.handle(
        _clickToOpenViewIdMeta,
        clickToOpenViewId.isAcceptableOrUnknown(
          data['click_to_open_view_id']!,
          _clickToOpenViewIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {packageName, viewId},
  ];
  @override
  BrowserConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BrowserConfig(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      packageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_name'],
      )!,
      viewId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}view_id'],
      )!,
      viewType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}view_type'],
      )!,
      clearUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}clear_url'],
      )!,
      detectionMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detection_method'],
      )!,
      extractionMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extraction_method'],
      )!,
      clickToOpenViewId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}click_to_open_view_id'],
      ),
    );
  }

  @override
  $BrowserConfigsTable createAlias(String alias) {
    return $BrowserConfigsTable(attachedDatabase, alias);
  }
}

class BrowserConfig extends DataClass implements Insertable<BrowserConfig> {
  final int id;
  final String packageName;
  final String viewId;
  final int viewType;
  final bool clearUrl;
  final String detectionMethod;
  final String extractionMethod;
  final String? clickToOpenViewId;
  const BrowserConfig({
    required this.id,
    required this.packageName,
    required this.viewId,
    required this.viewType,
    required this.clearUrl,
    required this.detectionMethod,
    required this.extractionMethod,
    this.clickToOpenViewId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['package_name'] = Variable<String>(packageName);
    map['view_id'] = Variable<String>(viewId);
    map['view_type'] = Variable<int>(viewType);
    map['clear_url'] = Variable<bool>(clearUrl);
    map['detection_method'] = Variable<String>(detectionMethod);
    map['extraction_method'] = Variable<String>(extractionMethod);
    if (!nullToAbsent || clickToOpenViewId != null) {
      map['click_to_open_view_id'] = Variable<String>(clickToOpenViewId);
    }
    return map;
  }

  BrowserConfigsCompanion toCompanion(bool nullToAbsent) {
    return BrowserConfigsCompanion(
      id: Value(id),
      packageName: Value(packageName),
      viewId: Value(viewId),
      viewType: Value(viewType),
      clearUrl: Value(clearUrl),
      detectionMethod: Value(detectionMethod),
      extractionMethod: Value(extractionMethod),
      clickToOpenViewId: clickToOpenViewId == null && nullToAbsent
          ? const Value.absent()
          : Value(clickToOpenViewId),
    );
  }

  factory BrowserConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BrowserConfig(
      id: serializer.fromJson<int>(json['id']),
      packageName: serializer.fromJson<String>(json['packageName']),
      viewId: serializer.fromJson<String>(json['viewId']),
      viewType: serializer.fromJson<int>(json['viewType']),
      clearUrl: serializer.fromJson<bool>(json['clearUrl']),
      detectionMethod: serializer.fromJson<String>(json['detectionMethod']),
      extractionMethod: serializer.fromJson<String>(json['extractionMethod']),
      clickToOpenViewId: serializer.fromJson<String?>(
        json['clickToOpenViewId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'packageName': serializer.toJson<String>(packageName),
      'viewId': serializer.toJson<String>(viewId),
      'viewType': serializer.toJson<int>(viewType),
      'clearUrl': serializer.toJson<bool>(clearUrl),
      'detectionMethod': serializer.toJson<String>(detectionMethod),
      'extractionMethod': serializer.toJson<String>(extractionMethod),
      'clickToOpenViewId': serializer.toJson<String?>(clickToOpenViewId),
    };
  }

  BrowserConfig copyWith({
    int? id,
    String? packageName,
    String? viewId,
    int? viewType,
    bool? clearUrl,
    String? detectionMethod,
    String? extractionMethod,
    Value<String?> clickToOpenViewId = const Value.absent(),
  }) => BrowserConfig(
    id: id ?? this.id,
    packageName: packageName ?? this.packageName,
    viewId: viewId ?? this.viewId,
    viewType: viewType ?? this.viewType,
    clearUrl: clearUrl ?? this.clearUrl,
    detectionMethod: detectionMethod ?? this.detectionMethod,
    extractionMethod: extractionMethod ?? this.extractionMethod,
    clickToOpenViewId: clickToOpenViewId.present
        ? clickToOpenViewId.value
        : this.clickToOpenViewId,
  );
  BrowserConfig copyWithCompanion(BrowserConfigsCompanion data) {
    return BrowserConfig(
      id: data.id.present ? data.id.value : this.id,
      packageName: data.packageName.present
          ? data.packageName.value
          : this.packageName,
      viewId: data.viewId.present ? data.viewId.value : this.viewId,
      viewType: data.viewType.present ? data.viewType.value : this.viewType,
      clearUrl: data.clearUrl.present ? data.clearUrl.value : this.clearUrl,
      detectionMethod: data.detectionMethod.present
          ? data.detectionMethod.value
          : this.detectionMethod,
      extractionMethod: data.extractionMethod.present
          ? data.extractionMethod.value
          : this.extractionMethod,
      clickToOpenViewId: data.clickToOpenViewId.present
          ? data.clickToOpenViewId.value
          : this.clickToOpenViewId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BrowserConfig(')
          ..write('id: $id, ')
          ..write('packageName: $packageName, ')
          ..write('viewId: $viewId, ')
          ..write('viewType: $viewType, ')
          ..write('clearUrl: $clearUrl, ')
          ..write('detectionMethod: $detectionMethod, ')
          ..write('extractionMethod: $extractionMethod, ')
          ..write('clickToOpenViewId: $clickToOpenViewId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    packageName,
    viewId,
    viewType,
    clearUrl,
    detectionMethod,
    extractionMethod,
    clickToOpenViewId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrowserConfig &&
          other.id == this.id &&
          other.packageName == this.packageName &&
          other.viewId == this.viewId &&
          other.viewType == this.viewType &&
          other.clearUrl == this.clearUrl &&
          other.detectionMethod == this.detectionMethod &&
          other.extractionMethod == this.extractionMethod &&
          other.clickToOpenViewId == this.clickToOpenViewId);
}

class BrowserConfigsCompanion extends UpdateCompanion<BrowserConfig> {
  final Value<int> id;
  final Value<String> packageName;
  final Value<String> viewId;
  final Value<int> viewType;
  final Value<bool> clearUrl;
  final Value<String> detectionMethod;
  final Value<String> extractionMethod;
  final Value<String?> clickToOpenViewId;
  const BrowserConfigsCompanion({
    this.id = const Value.absent(),
    this.packageName = const Value.absent(),
    this.viewId = const Value.absent(),
    this.viewType = const Value.absent(),
    this.clearUrl = const Value.absent(),
    this.detectionMethod = const Value.absent(),
    this.extractionMethod = const Value.absent(),
    this.clickToOpenViewId = const Value.absent(),
  });
  BrowserConfigsCompanion.insert({
    this.id = const Value.absent(),
    required String packageName,
    required String viewId,
    this.viewType = const Value.absent(),
    this.clearUrl = const Value.absent(),
    this.detectionMethod = const Value.absent(),
    this.extractionMethod = const Value.absent(),
    this.clickToOpenViewId = const Value.absent(),
  }) : packageName = Value(packageName),
       viewId = Value(viewId);
  static Insertable<BrowserConfig> custom({
    Expression<int>? id,
    Expression<String>? packageName,
    Expression<String>? viewId,
    Expression<int>? viewType,
    Expression<bool>? clearUrl,
    Expression<String>? detectionMethod,
    Expression<String>? extractionMethod,
    Expression<String>? clickToOpenViewId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (packageName != null) 'package_name': packageName,
      if (viewId != null) 'view_id': viewId,
      if (viewType != null) 'view_type': viewType,
      if (clearUrl != null) 'clear_url': clearUrl,
      if (detectionMethod != null) 'detection_method': detectionMethod,
      if (extractionMethod != null) 'extraction_method': extractionMethod,
      if (clickToOpenViewId != null) 'click_to_open_view_id': clickToOpenViewId,
    });
  }

  BrowserConfigsCompanion copyWith({
    Value<int>? id,
    Value<String>? packageName,
    Value<String>? viewId,
    Value<int>? viewType,
    Value<bool>? clearUrl,
    Value<String>? detectionMethod,
    Value<String>? extractionMethod,
    Value<String?>? clickToOpenViewId,
  }) {
    return BrowserConfigsCompanion(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      viewId: viewId ?? this.viewId,
      viewType: viewType ?? this.viewType,
      clearUrl: clearUrl ?? this.clearUrl,
      detectionMethod: detectionMethod ?? this.detectionMethod,
      extractionMethod: extractionMethod ?? this.extractionMethod,
      clickToOpenViewId: clickToOpenViewId ?? this.clickToOpenViewId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (packageName.present) {
      map['package_name'] = Variable<String>(packageName.value);
    }
    if (viewId.present) {
      map['view_id'] = Variable<String>(viewId.value);
    }
    if (viewType.present) {
      map['view_type'] = Variable<int>(viewType.value);
    }
    if (clearUrl.present) {
      map['clear_url'] = Variable<bool>(clearUrl.value);
    }
    if (detectionMethod.present) {
      map['detection_method'] = Variable<String>(detectionMethod.value);
    }
    if (extractionMethod.present) {
      map['extraction_method'] = Variable<String>(extractionMethod.value);
    }
    if (clickToOpenViewId.present) {
      map['click_to_open_view_id'] = Variable<String>(clickToOpenViewId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BrowserConfigsCompanion(')
          ..write('id: $id, ')
          ..write('packageName: $packageName, ')
          ..write('viewId: $viewId, ')
          ..write('viewType: $viewType, ')
          ..write('clearUrl: $clearUrl, ')
          ..write('detectionMethod: $detectionMethod, ')
          ..write('extractionMethod: $extractionMethod, ')
          ..write('clickToOpenViewId: $clickToOpenViewId')
          ..write(')'))
        .toString();
  }
}

class $AdultContentSitesTable extends AdultContentSites
    with TableInfo<$AdultContentSitesTable, AdultContentSite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AdultContentSitesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _domainMeta = const VerificationMeta('domain');
  @override
  late final GeneratedColumn<String> domain = GeneratedColumn<String>(
    'domain',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [domain];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'adult_content_sites';
  @override
  VerificationContext validateIntegrity(
    Insertable<AdultContentSite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('domain')) {
      context.handle(
        _domainMeta,
        domain.isAcceptableOrUnknown(data['domain']!, _domainMeta),
      );
    } else if (isInserting) {
      context.missing(_domainMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {domain};
  @override
  AdultContentSite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AdultContentSite(
      domain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}domain'],
      )!,
    );
  }

  @override
  $AdultContentSitesTable createAlias(String alias) {
    return $AdultContentSitesTable(attachedDatabase, alias);
  }
}

class AdultContentSite extends DataClass
    implements Insertable<AdultContentSite> {
  final String domain;
  const AdultContentSite({required this.domain});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['domain'] = Variable<String>(domain);
    return map;
  }

  AdultContentSitesCompanion toCompanion(bool nullToAbsent) {
    return AdultContentSitesCompanion(domain: Value(domain));
  }

  factory AdultContentSite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AdultContentSite(
      domain: serializer.fromJson<String>(json['domain']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'domain': serializer.toJson<String>(domain)};
  }

  AdultContentSite copyWith({String? domain}) =>
      AdultContentSite(domain: domain ?? this.domain);
  AdultContentSite copyWithCompanion(AdultContentSitesCompanion data) {
    return AdultContentSite(
      domain: data.domain.present ? data.domain.value : this.domain,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AdultContentSite(')
          ..write('domain: $domain')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => domain.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AdultContentSite && other.domain == this.domain);
}

class AdultContentSitesCompanion extends UpdateCompanion<AdultContentSite> {
  final Value<String> domain;
  final Value<int> rowid;
  const AdultContentSitesCompanion({
    this.domain = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AdultContentSitesCompanion.insert({
    required String domain,
    this.rowid = const Value.absent(),
  }) : domain = Value(domain);
  static Insertable<AdultContentSite> custom({
    Expression<String>? domain,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (domain != null) 'domain': domain,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AdultContentSitesCompanion copyWith({
    Value<String>? domain,
    Value<int>? rowid,
  }) {
    return AdultContentSitesCompanion(
      domain: domain ?? this.domain,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (domain.present) {
      map['domain'] = Variable<String>(domain.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AdultContentSitesCompanion(')
          ..write('domain: $domain, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PomodoroSessionsTable extends PomodoroSessions
    with TableInfo<$PomodoroSessionsTable, PomodoroSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PomodoroSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workMsMeta = const VerificationMeta('workMs');
  @override
  late final GeneratedColumn<int> workMs = GeneratedColumn<int>(
    'work_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _breakMsMeta = const VerificationMeta(
    'breakMs',
  );
  @override
  late final GeneratedColumn<int> breakMs = GeneratedColumn<int>(
    'break_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cyclesMeta = const VerificationMeta('cycles');
  @override
  late final GeneratedColumn<int> cycles = GeneratedColumn<int>(
    'cycles',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<int> startTime = GeneratedColumn<int>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<int> endTime = GeneratedColumn<int>(
    'end_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isStoppedManuallyMeta = const VerificationMeta(
    'isStoppedManually',
  );
  @override
  late final GeneratedColumn<bool> isStoppedManually = GeneratedColumn<bool>(
    'is_stopped_manually',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_stopped_manually" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    workMs,
    breakMs,
    cycles,
    startTime,
    endTime,
    isStoppedManually,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pomodoro_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PomodoroSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('work_ms')) {
      context.handle(
        _workMsMeta,
        workMs.isAcceptableOrUnknown(data['work_ms']!, _workMsMeta),
      );
    } else if (isInserting) {
      context.missing(_workMsMeta);
    }
    if (data.containsKey('break_ms')) {
      context.handle(
        _breakMsMeta,
        breakMs.isAcceptableOrUnknown(data['break_ms']!, _breakMsMeta),
      );
    } else if (isInserting) {
      context.missing(_breakMsMeta);
    }
    if (data.containsKey('cycles')) {
      context.handle(
        _cyclesMeta,
        cycles.isAcceptableOrUnknown(data['cycles']!, _cyclesMeta),
      );
    } else if (isInserting) {
      context.missing(_cyclesMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('is_stopped_manually')) {
      context.handle(
        _isStoppedManuallyMeta,
        isStoppedManually.isAcceptableOrUnknown(
          data['is_stopped_manually']!,
          _isStoppedManuallyMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PomodoroSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PomodoroSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      workMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}work_ms'],
      )!,
      breakMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}break_ms'],
      )!,
      cycles: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cycles'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_time'],
      )!,
      isStoppedManually: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_stopped_manually'],
      )!,
    );
  }

  @override
  $PomodoroSessionsTable createAlias(String alias) {
    return $PomodoroSessionsTable(attachedDatabase, alias);
  }
}

class PomodoroSession extends DataClass implements Insertable<PomodoroSession> {
  final int id;
  final int profileId;
  final int workMs;
  final int breakMs;
  final int cycles;
  final int startTime;
  final int endTime;
  final bool isStoppedManually;
  const PomodoroSession({
    required this.id,
    required this.profileId,
    required this.workMs,
    required this.breakMs,
    required this.cycles,
    required this.startTime,
    required this.endTime,
    required this.isStoppedManually,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['work_ms'] = Variable<int>(workMs);
    map['break_ms'] = Variable<int>(breakMs);
    map['cycles'] = Variable<int>(cycles);
    map['start_time'] = Variable<int>(startTime);
    map['end_time'] = Variable<int>(endTime);
    map['is_stopped_manually'] = Variable<bool>(isStoppedManually);
    return map;
  }

  PomodoroSessionsCompanion toCompanion(bool nullToAbsent) {
    return PomodoroSessionsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      workMs: Value(workMs),
      breakMs: Value(breakMs),
      cycles: Value(cycles),
      startTime: Value(startTime),
      endTime: Value(endTime),
      isStoppedManually: Value(isStoppedManually),
    );
  }

  factory PomodoroSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PomodoroSession(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      workMs: serializer.fromJson<int>(json['workMs']),
      breakMs: serializer.fromJson<int>(json['breakMs']),
      cycles: serializer.fromJson<int>(json['cycles']),
      startTime: serializer.fromJson<int>(json['startTime']),
      endTime: serializer.fromJson<int>(json['endTime']),
      isStoppedManually: serializer.fromJson<bool>(json['isStoppedManually']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'workMs': serializer.toJson<int>(workMs),
      'breakMs': serializer.toJson<int>(breakMs),
      'cycles': serializer.toJson<int>(cycles),
      'startTime': serializer.toJson<int>(startTime),
      'endTime': serializer.toJson<int>(endTime),
      'isStoppedManually': serializer.toJson<bool>(isStoppedManually),
    };
  }

  PomodoroSession copyWith({
    int? id,
    int? profileId,
    int? workMs,
    int? breakMs,
    int? cycles,
    int? startTime,
    int? endTime,
    bool? isStoppedManually,
  }) => PomodoroSession(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    workMs: workMs ?? this.workMs,
    breakMs: breakMs ?? this.breakMs,
    cycles: cycles ?? this.cycles,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    isStoppedManually: isStoppedManually ?? this.isStoppedManually,
  );
  PomodoroSession copyWithCompanion(PomodoroSessionsCompanion data) {
    return PomodoroSession(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      workMs: data.workMs.present ? data.workMs.value : this.workMs,
      breakMs: data.breakMs.present ? data.breakMs.value : this.breakMs,
      cycles: data.cycles.present ? data.cycles.value : this.cycles,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      isStoppedManually: data.isStoppedManually.present
          ? data.isStoppedManually.value
          : this.isStoppedManually,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PomodoroSession(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('workMs: $workMs, ')
          ..write('breakMs: $breakMs, ')
          ..write('cycles: $cycles, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('isStoppedManually: $isStoppedManually')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    workMs,
    breakMs,
    cycles,
    startTime,
    endTime,
    isStoppedManually,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PomodoroSession &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.workMs == this.workMs &&
          other.breakMs == this.breakMs &&
          other.cycles == this.cycles &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.isStoppedManually == this.isStoppedManually);
}

class PomodoroSessionsCompanion extends UpdateCompanion<PomodoroSession> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<int> workMs;
  final Value<int> breakMs;
  final Value<int> cycles;
  final Value<int> startTime;
  final Value<int> endTime;
  final Value<bool> isStoppedManually;
  const PomodoroSessionsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.workMs = const Value.absent(),
    this.breakMs = const Value.absent(),
    this.cycles = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.isStoppedManually = const Value.absent(),
  });
  PomodoroSessionsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required int workMs,
    required int breakMs,
    required int cycles,
    required int startTime,
    required int endTime,
    this.isStoppedManually = const Value.absent(),
  }) : profileId = Value(profileId),
       workMs = Value(workMs),
       breakMs = Value(breakMs),
       cycles = Value(cycles),
       startTime = Value(startTime),
       endTime = Value(endTime);
  static Insertable<PomodoroSession> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<int>? workMs,
    Expression<int>? breakMs,
    Expression<int>? cycles,
    Expression<int>? startTime,
    Expression<int>? endTime,
    Expression<bool>? isStoppedManually,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (workMs != null) 'work_ms': workMs,
      if (breakMs != null) 'break_ms': breakMs,
      if (cycles != null) 'cycles': cycles,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (isStoppedManually != null) 'is_stopped_manually': isStoppedManually,
    });
  }

  PomodoroSessionsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<int>? workMs,
    Value<int>? breakMs,
    Value<int>? cycles,
    Value<int>? startTime,
    Value<int>? endTime,
    Value<bool>? isStoppedManually,
  }) {
    return PomodoroSessionsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      workMs: workMs ?? this.workMs,
      breakMs: breakMs ?? this.breakMs,
      cycles: cycles ?? this.cycles,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isStoppedManually: isStoppedManually ?? this.isStoppedManually,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (workMs.present) {
      map['work_ms'] = Variable<int>(workMs.value);
    }
    if (breakMs.present) {
      map['break_ms'] = Variable<int>(breakMs.value);
    }
    if (cycles.present) {
      map['cycles'] = Variable<int>(cycles.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<int>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<int>(endTime.value);
    }
    if (isStoppedManually.present) {
      map['is_stopped_manually'] = Variable<bool>(isStoppedManually.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PomodoroSessionsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('workMs: $workMs, ')
          ..write('breakMs: $breakMs, ')
          ..write('cycles: $cycles, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('isStoppedManually: $isStoppedManually')
          ..write(')'))
        .toString();
  }
}

class $BlockingConfigsTable extends BlockingConfigs
    with TableInfo<$BlockingConfigsTable, BlockingConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlockingConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configTypeMeta = const VerificationMeta(
    'configType',
  );
  @override
  late final GeneratedColumn<int> configType = GeneratedColumn<int>(
    'config_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _blockingMessageMeta = const VerificationMeta(
    'blockingMessage',
  );
  @override
  late final GeneratedColumn<String> blockingMessage = GeneratedColumn<String>(
    'blocking_message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _timeoutSecondsMeta = const VerificationMeta(
    'timeoutSeconds',
  );
  @override
  late final GeneratedColumn<int> timeoutSeconds = GeneratedColumn<int>(
    'timeout_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _customTitleMeta = const VerificationMeta(
    'customTitle',
  );
  @override
  late final GeneratedColumn<String> customTitle = GeneratedColumn<String>(
    'custom_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _customSubtitleMeta = const VerificationMeta(
    'customSubtitle',
  );
  @override
  late final GeneratedColumn<String> customSubtitle = GeneratedColumn<String>(
    'custom_subtitle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _customExitButtonTextMeta =
      const VerificationMeta('customExitButtonText');
  @override
  late final GeneratedColumn<String> customExitButtonText =
      GeneratedColumn<String>(
        'custom_exit_button_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _customColorHexMeta = const VerificationMeta(
    'customColorHex',
  );
  @override
  late final GeneratedColumn<String> customColorHex = GeneratedColumn<String>(
    'custom_color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#A85449'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    configType,
    blockingMessage,
    timeoutSeconds,
    customTitle,
    customSubtitle,
    customExitButtonText,
    customColorHex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blocking_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlockingConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('config_type')) {
      context.handle(
        _configTypeMeta,
        configType.isAcceptableOrUnknown(data['config_type']!, _configTypeMeta),
      );
    }
    if (data.containsKey('blocking_message')) {
      context.handle(
        _blockingMessageMeta,
        blockingMessage.isAcceptableOrUnknown(
          data['blocking_message']!,
          _blockingMessageMeta,
        ),
      );
    }
    if (data.containsKey('timeout_seconds')) {
      context.handle(
        _timeoutSecondsMeta,
        timeoutSeconds.isAcceptableOrUnknown(
          data['timeout_seconds']!,
          _timeoutSecondsMeta,
        ),
      );
    }
    if (data.containsKey('custom_title')) {
      context.handle(
        _customTitleMeta,
        customTitle.isAcceptableOrUnknown(
          data['custom_title']!,
          _customTitleMeta,
        ),
      );
    }
    if (data.containsKey('custom_subtitle')) {
      context.handle(
        _customSubtitleMeta,
        customSubtitle.isAcceptableOrUnknown(
          data['custom_subtitle']!,
          _customSubtitleMeta,
        ),
      );
    }
    if (data.containsKey('custom_exit_button_text')) {
      context.handle(
        _customExitButtonTextMeta,
        customExitButtonText.isAcceptableOrUnknown(
          data['custom_exit_button_text']!,
          _customExitButtonTextMeta,
        ),
      );
    }
    if (data.containsKey('custom_color_hex')) {
      context.handle(
        _customColorHexMeta,
        customColorHex.isAcceptableOrUnknown(
          data['custom_color_hex']!,
          _customColorHexMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BlockingConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlockingConfig(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      configType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}config_type'],
      )!,
      blockingMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blocking_message'],
      )!,
      timeoutSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timeout_seconds'],
      )!,
      customTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_title'],
      )!,
      customSubtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_subtitle'],
      )!,
      customExitButtonText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_exit_button_text'],
      )!,
      customColorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_color_hex'],
      )!,
    );
  }

  @override
  $BlockingConfigsTable createAlias(String alias) {
    return $BlockingConfigsTable(attachedDatabase, alias);
  }
}

class BlockingConfig extends DataClass implements Insertable<BlockingConfig> {
  final String id;
  final int configType;
  final String blockingMessage;
  final int timeoutSeconds;
  final String customTitle;
  final String customSubtitle;
  final String customExitButtonText;
  final String customColorHex;
  const BlockingConfig({
    required this.id,
    required this.configType,
    required this.blockingMessage,
    required this.timeoutSeconds,
    required this.customTitle,
    required this.customSubtitle,
    required this.customExitButtonText,
    required this.customColorHex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['config_type'] = Variable<int>(configType);
    map['blocking_message'] = Variable<String>(blockingMessage);
    map['timeout_seconds'] = Variable<int>(timeoutSeconds);
    map['custom_title'] = Variable<String>(customTitle);
    map['custom_subtitle'] = Variable<String>(customSubtitle);
    map['custom_exit_button_text'] = Variable<String>(customExitButtonText);
    map['custom_color_hex'] = Variable<String>(customColorHex);
    return map;
  }

  BlockingConfigsCompanion toCompanion(bool nullToAbsent) {
    return BlockingConfigsCompanion(
      id: Value(id),
      configType: Value(configType),
      blockingMessage: Value(blockingMessage),
      timeoutSeconds: Value(timeoutSeconds),
      customTitle: Value(customTitle),
      customSubtitle: Value(customSubtitle),
      customExitButtonText: Value(customExitButtonText),
      customColorHex: Value(customColorHex),
    );
  }

  factory BlockingConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlockingConfig(
      id: serializer.fromJson<String>(json['id']),
      configType: serializer.fromJson<int>(json['configType']),
      blockingMessage: serializer.fromJson<String>(json['blockingMessage']),
      timeoutSeconds: serializer.fromJson<int>(json['timeoutSeconds']),
      customTitle: serializer.fromJson<String>(json['customTitle']),
      customSubtitle: serializer.fromJson<String>(json['customSubtitle']),
      customExitButtonText: serializer.fromJson<String>(
        json['customExitButtonText'],
      ),
      customColorHex: serializer.fromJson<String>(json['customColorHex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'configType': serializer.toJson<int>(configType),
      'blockingMessage': serializer.toJson<String>(blockingMessage),
      'timeoutSeconds': serializer.toJson<int>(timeoutSeconds),
      'customTitle': serializer.toJson<String>(customTitle),
      'customSubtitle': serializer.toJson<String>(customSubtitle),
      'customExitButtonText': serializer.toJson<String>(customExitButtonText),
      'customColorHex': serializer.toJson<String>(customColorHex),
    };
  }

  BlockingConfig copyWith({
    String? id,
    int? configType,
    String? blockingMessage,
    int? timeoutSeconds,
    String? customTitle,
    String? customSubtitle,
    String? customExitButtonText,
    String? customColorHex,
  }) => BlockingConfig(
    id: id ?? this.id,
    configType: configType ?? this.configType,
    blockingMessage: blockingMessage ?? this.blockingMessage,
    timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    customTitle: customTitle ?? this.customTitle,
    customSubtitle: customSubtitle ?? this.customSubtitle,
    customExitButtonText: customExitButtonText ?? this.customExitButtonText,
    customColorHex: customColorHex ?? this.customColorHex,
  );
  BlockingConfig copyWithCompanion(BlockingConfigsCompanion data) {
    return BlockingConfig(
      id: data.id.present ? data.id.value : this.id,
      configType: data.configType.present
          ? data.configType.value
          : this.configType,
      blockingMessage: data.blockingMessage.present
          ? data.blockingMessage.value
          : this.blockingMessage,
      timeoutSeconds: data.timeoutSeconds.present
          ? data.timeoutSeconds.value
          : this.timeoutSeconds,
      customTitle: data.customTitle.present
          ? data.customTitle.value
          : this.customTitle,
      customSubtitle: data.customSubtitle.present
          ? data.customSubtitle.value
          : this.customSubtitle,
      customExitButtonText: data.customExitButtonText.present
          ? data.customExitButtonText.value
          : this.customExitButtonText,
      customColorHex: data.customColorHex.present
          ? data.customColorHex.value
          : this.customColorHex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlockingConfig(')
          ..write('id: $id, ')
          ..write('configType: $configType, ')
          ..write('blockingMessage: $blockingMessage, ')
          ..write('timeoutSeconds: $timeoutSeconds, ')
          ..write('customTitle: $customTitle, ')
          ..write('customSubtitle: $customSubtitle, ')
          ..write('customExitButtonText: $customExitButtonText, ')
          ..write('customColorHex: $customColorHex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    configType,
    blockingMessage,
    timeoutSeconds,
    customTitle,
    customSubtitle,
    customExitButtonText,
    customColorHex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockingConfig &&
          other.id == this.id &&
          other.configType == this.configType &&
          other.blockingMessage == this.blockingMessage &&
          other.timeoutSeconds == this.timeoutSeconds &&
          other.customTitle == this.customTitle &&
          other.customSubtitle == this.customSubtitle &&
          other.customExitButtonText == this.customExitButtonText &&
          other.customColorHex == this.customColorHex);
}

class BlockingConfigsCompanion extends UpdateCompanion<BlockingConfig> {
  final Value<String> id;
  final Value<int> configType;
  final Value<String> blockingMessage;
  final Value<int> timeoutSeconds;
  final Value<String> customTitle;
  final Value<String> customSubtitle;
  final Value<String> customExitButtonText;
  final Value<String> customColorHex;
  final Value<int> rowid;
  const BlockingConfigsCompanion({
    this.id = const Value.absent(),
    this.configType = const Value.absent(),
    this.blockingMessage = const Value.absent(),
    this.timeoutSeconds = const Value.absent(),
    this.customTitle = const Value.absent(),
    this.customSubtitle = const Value.absent(),
    this.customExitButtonText = const Value.absent(),
    this.customColorHex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlockingConfigsCompanion.insert({
    required String id,
    this.configType = const Value.absent(),
    this.blockingMessage = const Value.absent(),
    this.timeoutSeconds = const Value.absent(),
    this.customTitle = const Value.absent(),
    this.customSubtitle = const Value.absent(),
    this.customExitButtonText = const Value.absent(),
    this.customColorHex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<BlockingConfig> custom({
    Expression<String>? id,
    Expression<int>? configType,
    Expression<String>? blockingMessage,
    Expression<int>? timeoutSeconds,
    Expression<String>? customTitle,
    Expression<String>? customSubtitle,
    Expression<String>? customExitButtonText,
    Expression<String>? customColorHex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (configType != null) 'config_type': configType,
      if (blockingMessage != null) 'blocking_message': blockingMessage,
      if (timeoutSeconds != null) 'timeout_seconds': timeoutSeconds,
      if (customTitle != null) 'custom_title': customTitle,
      if (customSubtitle != null) 'custom_subtitle': customSubtitle,
      if (customExitButtonText != null)
        'custom_exit_button_text': customExitButtonText,
      if (customColorHex != null) 'custom_color_hex': customColorHex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlockingConfigsCompanion copyWith({
    Value<String>? id,
    Value<int>? configType,
    Value<String>? blockingMessage,
    Value<int>? timeoutSeconds,
    Value<String>? customTitle,
    Value<String>? customSubtitle,
    Value<String>? customExitButtonText,
    Value<String>? customColorHex,
    Value<int>? rowid,
  }) {
    return BlockingConfigsCompanion(
      id: id ?? this.id,
      configType: configType ?? this.configType,
      blockingMessage: blockingMessage ?? this.blockingMessage,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      customTitle: customTitle ?? this.customTitle,
      customSubtitle: customSubtitle ?? this.customSubtitle,
      customExitButtonText: customExitButtonText ?? this.customExitButtonText,
      customColorHex: customColorHex ?? this.customColorHex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (configType.present) {
      map['config_type'] = Variable<int>(configType.value);
    }
    if (blockingMessage.present) {
      map['blocking_message'] = Variable<String>(blockingMessage.value);
    }
    if (timeoutSeconds.present) {
      map['timeout_seconds'] = Variable<int>(timeoutSeconds.value);
    }
    if (customTitle.present) {
      map['custom_title'] = Variable<String>(customTitle.value);
    }
    if (customSubtitle.present) {
      map['custom_subtitle'] = Variable<String>(customSubtitle.value);
    }
    if (customExitButtonText.present) {
      map['custom_exit_button_text'] = Variable<String>(
        customExitButtonText.value,
      );
    }
    if (customColorHex.present) {
      map['custom_color_hex'] = Variable<String>(customColorHex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlockingConfigsCompanion(')
          ..write('id: $id, ')
          ..write('configType: $configType, ')
          ..write('blockingMessage: $blockingMessage, ')
          ..write('timeoutSeconds: $timeoutSeconds, ')
          ..write('customTitle: $customTitle, ')
          ..write('customSubtitle: $customSubtitle, ')
          ..write('customExitButtonText: $customExitButtonText, ')
          ..write('customColorHex: $customColorHex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MoodCheckInsTable extends MoodCheckIns
    with TableInfo<$MoodCheckInsTable, MoodCheckIn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoodCheckInsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<int> mood = GeneratedColumn<int>(
    'mood',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mood,
    day,
    createdAt,
    note,
    tagsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mood_check_ins';
  @override
  VerificationContext validateIntegrity(
    Insertable<MoodCheckIn> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    } else if (isInserting) {
      context.missing(_moodMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MoodCheckIn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MoodCheckIn(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mood'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      ),
    );
  }

  @override
  $MoodCheckInsTable createAlias(String alias) {
    return $MoodCheckInsTable(attachedDatabase, alias);
  }
}

class MoodCheckIn extends DataClass implements Insertable<MoodCheckIn> {
  final int id;
  final int mood;
  final String day;
  final int createdAt;
  final String? note;
  final String? tagsJson;
  const MoodCheckIn({
    required this.id,
    required this.mood,
    required this.day,
    required this.createdAt,
    this.note,
    this.tagsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mood'] = Variable<int>(mood);
    map['day'] = Variable<String>(day);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || tagsJson != null) {
      map['tags_json'] = Variable<String>(tagsJson);
    }
    return map;
  }

  MoodCheckInsCompanion toCompanion(bool nullToAbsent) {
    return MoodCheckInsCompanion(
      id: Value(id),
      mood: Value(mood),
      day: Value(day),
      createdAt: Value(createdAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      tagsJson: tagsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(tagsJson),
    );
  }

  factory MoodCheckIn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MoodCheckIn(
      id: serializer.fromJson<int>(json['id']),
      mood: serializer.fromJson<int>(json['mood']),
      day: serializer.fromJson<String>(json['day']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      note: serializer.fromJson<String?>(json['note']),
      tagsJson: serializer.fromJson<String?>(json['tagsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mood': serializer.toJson<int>(mood),
      'day': serializer.toJson<String>(day),
      'createdAt': serializer.toJson<int>(createdAt),
      'note': serializer.toJson<String?>(note),
      'tagsJson': serializer.toJson<String?>(tagsJson),
    };
  }

  MoodCheckIn copyWith({
    int? id,
    int? mood,
    String? day,
    int? createdAt,
    Value<String?> note = const Value.absent(),
    Value<String?> tagsJson = const Value.absent(),
  }) => MoodCheckIn(
    id: id ?? this.id,
    mood: mood ?? this.mood,
    day: day ?? this.day,
    createdAt: createdAt ?? this.createdAt,
    note: note.present ? note.value : this.note,
    tagsJson: tagsJson.present ? tagsJson.value : this.tagsJson,
  );
  MoodCheckIn copyWithCompanion(MoodCheckInsCompanion data) {
    return MoodCheckIn(
      id: data.id.present ? data.id.value : this.id,
      mood: data.mood.present ? data.mood.value : this.mood,
      day: data.day.present ? data.day.value : this.day,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      note: data.note.present ? data.note.value : this.note,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MoodCheckIn(')
          ..write('id: $id, ')
          ..write('mood: $mood, ')
          ..write('day: $day, ')
          ..write('createdAt: $createdAt, ')
          ..write('note: $note, ')
          ..write('tagsJson: $tagsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mood, day, createdAt, note, tagsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MoodCheckIn &&
          other.id == this.id &&
          other.mood == this.mood &&
          other.day == this.day &&
          other.createdAt == this.createdAt &&
          other.note == this.note &&
          other.tagsJson == this.tagsJson);
}

class MoodCheckInsCompanion extends UpdateCompanion<MoodCheckIn> {
  final Value<int> id;
  final Value<int> mood;
  final Value<String> day;
  final Value<int> createdAt;
  final Value<String?> note;
  final Value<String?> tagsJson;
  const MoodCheckInsCompanion({
    this.id = const Value.absent(),
    this.mood = const Value.absent(),
    this.day = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.note = const Value.absent(),
    this.tagsJson = const Value.absent(),
  });
  MoodCheckInsCompanion.insert({
    this.id = const Value.absent(),
    required int mood,
    required String day,
    required int createdAt,
    this.note = const Value.absent(),
    this.tagsJson = const Value.absent(),
  }) : mood = Value(mood),
       day = Value(day),
       createdAt = Value(createdAt);
  static Insertable<MoodCheckIn> custom({
    Expression<int>? id,
    Expression<int>? mood,
    Expression<String>? day,
    Expression<int>? createdAt,
    Expression<String>? note,
    Expression<String>? tagsJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mood != null) 'mood': mood,
      if (day != null) 'day': day,
      if (createdAt != null) 'created_at': createdAt,
      if (note != null) 'note': note,
      if (tagsJson != null) 'tags_json': tagsJson,
    });
  }

  MoodCheckInsCompanion copyWith({
    Value<int>? id,
    Value<int>? mood,
    Value<String>? day,
    Value<int>? createdAt,
    Value<String?>? note,
    Value<String?>? tagsJson,
  }) {
    return MoodCheckInsCompanion(
      id: id ?? this.id,
      mood: mood ?? this.mood,
      day: day ?? this.day,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      tagsJson: tagsJson ?? this.tagsJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mood.present) {
      map['mood'] = Variable<int>(mood.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoodCheckInsCompanion(')
          ..write('id: $id, ')
          ..write('mood: $mood, ')
          ..write('day: $day, ')
          ..write('createdAt: $createdAt, ')
          ..write('note: $note, ')
          ..write('tagsJson: $tagsJson')
          ..write(')'))
        .toString();
  }
}

class $EmergencyUnblocksTable extends EmergencyUnblocks
    with TableInfo<$EmergencyUnblocksTable, EmergencyUnblock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmergencyUnblocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'emergency_unblocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmergencyUnblock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EmergencyUnblock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmergencyUnblock(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $EmergencyUnblocksTable createAlias(String alias) {
    return $EmergencyUnblocksTable(attachedDatabase, alias);
  }
}

class EmergencyUnblock extends DataClass
    implements Insertable<EmergencyUnblock> {
  final int id;
  final int timestamp;
  const EmergencyUnblock({required this.id, required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<int>(timestamp);
    return map;
  }

  EmergencyUnblocksCompanion toCompanion(bool nullToAbsent) {
    return EmergencyUnblocksCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
    );
  }

  factory EmergencyUnblock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmergencyUnblock(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<int>(timestamp),
    };
  }

  EmergencyUnblock copyWith({int? id, int? timestamp}) => EmergencyUnblock(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
  );
  EmergencyUnblock copyWithCompanion(EmergencyUnblocksCompanion data) {
    return EmergencyUnblock(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmergencyUnblock(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmergencyUnblock &&
          other.id == this.id &&
          other.timestamp == this.timestamp);
}

class EmergencyUnblocksCompanion extends UpdateCompanion<EmergencyUnblock> {
  final Value<int> id;
  final Value<int> timestamp;
  const EmergencyUnblocksCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  EmergencyUnblocksCompanion.insert({
    this.id = const Value.absent(),
    required int timestamp,
  }) : timestamp = Value(timestamp);
  static Insertable<EmergencyUnblock> custom({
    Expression<int>? id,
    Expression<int>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  EmergencyUnblocksCompanion copyWith({Value<int>? id, Value<int>? timestamp}) {
    return EmergencyUnblocksCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmergencyUnblocksCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $UsedBackdoorCodesTable extends UsedBackdoorCodes
    with TableInfo<$UsedBackdoorCodesTable, UsedBackdoorCode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsedBackdoorCodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _usedAtMeta = const VerificationMeta('usedAt');
  @override
  late final GeneratedColumn<int> usedAt = GeneratedColumn<int>(
    'used_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, code, usedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'used_backdoor_codes';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsedBackdoorCode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('used_at')) {
      context.handle(
        _usedAtMeta,
        usedAt.isAcceptableOrUnknown(data['used_at']!, _usedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_usedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UsedBackdoorCode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsedBackdoorCode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      usedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}used_at'],
      )!,
    );
  }

  @override
  $UsedBackdoorCodesTable createAlias(String alias) {
    return $UsedBackdoorCodesTable(attachedDatabase, alias);
  }
}

class UsedBackdoorCode extends DataClass
    implements Insertable<UsedBackdoorCode> {
  final int id;
  final String code;
  final int usedAt;
  const UsedBackdoorCode({
    required this.id,
    required this.code,
    required this.usedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['code'] = Variable<String>(code);
    map['used_at'] = Variable<int>(usedAt);
    return map;
  }

  UsedBackdoorCodesCompanion toCompanion(bool nullToAbsent) {
    return UsedBackdoorCodesCompanion(
      id: Value(id),
      code: Value(code),
      usedAt: Value(usedAt),
    );
  }

  factory UsedBackdoorCode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsedBackdoorCode(
      id: serializer.fromJson<int>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      usedAt: serializer.fromJson<int>(json['usedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'code': serializer.toJson<String>(code),
      'usedAt': serializer.toJson<int>(usedAt),
    };
  }

  UsedBackdoorCode copyWith({int? id, String? code, int? usedAt}) =>
      UsedBackdoorCode(
        id: id ?? this.id,
        code: code ?? this.code,
        usedAt: usedAt ?? this.usedAt,
      );
  UsedBackdoorCode copyWithCompanion(UsedBackdoorCodesCompanion data) {
    return UsedBackdoorCode(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      usedAt: data.usedAt.present ? data.usedAt.value : this.usedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsedBackdoorCode(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('usedAt: $usedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, usedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsedBackdoorCode &&
          other.id == this.id &&
          other.code == this.code &&
          other.usedAt == this.usedAt);
}

class UsedBackdoorCodesCompanion extends UpdateCompanion<UsedBackdoorCode> {
  final Value<int> id;
  final Value<String> code;
  final Value<int> usedAt;
  const UsedBackdoorCodesCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.usedAt = const Value.absent(),
  });
  UsedBackdoorCodesCompanion.insert({
    this.id = const Value.absent(),
    required String code,
    required int usedAt,
  }) : code = Value(code),
       usedAt = Value(usedAt);
  static Insertable<UsedBackdoorCode> custom({
    Expression<int>? id,
    Expression<String>? code,
    Expression<int>? usedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (usedAt != null) 'used_at': usedAt,
    });
  }

  UsedBackdoorCodesCompanion copyWith({
    Value<int>? id,
    Value<String>? code,
    Value<int>? usedAt,
  }) {
    return UsedBackdoorCodesCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      usedAt: usedAt ?? this.usedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (usedAt.present) {
      map['used_at'] = Variable<int>(usedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsedBackdoorCodesCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('usedAt: $usedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RestrictedAccessEventsTable extends RestrictedAccessEvents
    with TableInfo<$RestrictedAccessEventsTable, RestrictedAccessEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RestrictedAccessEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayStartDateMeta = const VerificationMeta(
    'dayStartDate',
  );
  @override
  late final GeneratedColumn<String> dayStartDate = GeneratedColumn<String>(
    'day_start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packageNameMeta = const VerificationMeta(
    'packageName',
  );
  @override
  late final GeneratedColumn<String> packageName = GeneratedColumn<String>(
    'package_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<int> eventType = GeneratedColumn<int>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restrictionTypeMeta = const VerificationMeta(
    'restrictionType',
  );
  @override
  late final GeneratedColumn<int> restrictionType = GeneratedColumn<int>(
    'restriction_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    occurredAt,
    dayStartDate,
    packageName,
    eventType,
    restrictionType,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'restricted_access_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<RestrictedAccessEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('day_start_date')) {
      context.handle(
        _dayStartDateMeta,
        dayStartDate.isAcceptableOrUnknown(
          data['day_start_date']!,
          _dayStartDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dayStartDateMeta);
    }
    if (data.containsKey('package_name')) {
      context.handle(
        _packageNameMeta,
        packageName.isAcceptableOrUnknown(
          data['package_name']!,
          _packageNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_packageNameMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('restriction_type')) {
      context.handle(
        _restrictionTypeMeta,
        restrictionType.isAcceptableOrUnknown(
          data['restriction_type']!,
          _restrictionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_restrictionTypeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RestrictedAccessEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RestrictedAccessEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at'],
      )!,
      dayStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_start_date'],
      )!,
      packageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_name'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_type'],
      )!,
      restrictionType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}restriction_type'],
      )!,
    );
  }

  @override
  $RestrictedAccessEventsTable createAlias(String alias) {
    return $RestrictedAccessEventsTable(attachedDatabase, alias);
  }
}

class RestrictedAccessEvent extends DataClass
    implements Insertable<RestrictedAccessEvent> {
  final int id;
  final int occurredAt;
  final String dayStartDate;
  final String packageName;
  final int eventType;
  final int restrictionType;
  const RestrictedAccessEvent({
    required this.id,
    required this.occurredAt,
    required this.dayStartDate,
    required this.packageName,
    required this.eventType,
    required this.restrictionType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['occurred_at'] = Variable<int>(occurredAt);
    map['day_start_date'] = Variable<String>(dayStartDate);
    map['package_name'] = Variable<String>(packageName);
    map['event_type'] = Variable<int>(eventType);
    map['restriction_type'] = Variable<int>(restrictionType);
    return map;
  }

  RestrictedAccessEventsCompanion toCompanion(bool nullToAbsent) {
    return RestrictedAccessEventsCompanion(
      id: Value(id),
      occurredAt: Value(occurredAt),
      dayStartDate: Value(dayStartDate),
      packageName: Value(packageName),
      eventType: Value(eventType),
      restrictionType: Value(restrictionType),
    );
  }

  factory RestrictedAccessEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RestrictedAccessEvent(
      id: serializer.fromJson<int>(json['id']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
      dayStartDate: serializer.fromJson<String>(json['dayStartDate']),
      packageName: serializer.fromJson<String>(json['packageName']),
      eventType: serializer.fromJson<int>(json['eventType']),
      restrictionType: serializer.fromJson<int>(json['restrictionType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'occurredAt': serializer.toJson<int>(occurredAt),
      'dayStartDate': serializer.toJson<String>(dayStartDate),
      'packageName': serializer.toJson<String>(packageName),
      'eventType': serializer.toJson<int>(eventType),
      'restrictionType': serializer.toJson<int>(restrictionType),
    };
  }

  RestrictedAccessEvent copyWith({
    int? id,
    int? occurredAt,
    String? dayStartDate,
    String? packageName,
    int? eventType,
    int? restrictionType,
  }) => RestrictedAccessEvent(
    id: id ?? this.id,
    occurredAt: occurredAt ?? this.occurredAt,
    dayStartDate: dayStartDate ?? this.dayStartDate,
    packageName: packageName ?? this.packageName,
    eventType: eventType ?? this.eventType,
    restrictionType: restrictionType ?? this.restrictionType,
  );
  RestrictedAccessEvent copyWithCompanion(
    RestrictedAccessEventsCompanion data,
  ) {
    return RestrictedAccessEvent(
      id: data.id.present ? data.id.value : this.id,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      dayStartDate: data.dayStartDate.present
          ? data.dayStartDate.value
          : this.dayStartDate,
      packageName: data.packageName.present
          ? data.packageName.value
          : this.packageName,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      restrictionType: data.restrictionType.present
          ? data.restrictionType.value
          : this.restrictionType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RestrictedAccessEvent(')
          ..write('id: $id, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('dayStartDate: $dayStartDate, ')
          ..write('packageName: $packageName, ')
          ..write('eventType: $eventType, ')
          ..write('restrictionType: $restrictionType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    occurredAt,
    dayStartDate,
    packageName,
    eventType,
    restrictionType,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RestrictedAccessEvent &&
          other.id == this.id &&
          other.occurredAt == this.occurredAt &&
          other.dayStartDate == this.dayStartDate &&
          other.packageName == this.packageName &&
          other.eventType == this.eventType &&
          other.restrictionType == this.restrictionType);
}

class RestrictedAccessEventsCompanion
    extends UpdateCompanion<RestrictedAccessEvent> {
  final Value<int> id;
  final Value<int> occurredAt;
  final Value<String> dayStartDate;
  final Value<String> packageName;
  final Value<int> eventType;
  final Value<int> restrictionType;
  const RestrictedAccessEventsCompanion({
    this.id = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.dayStartDate = const Value.absent(),
    this.packageName = const Value.absent(),
    this.eventType = const Value.absent(),
    this.restrictionType = const Value.absent(),
  });
  RestrictedAccessEventsCompanion.insert({
    this.id = const Value.absent(),
    required int occurredAt,
    required String dayStartDate,
    required String packageName,
    required int eventType,
    required int restrictionType,
  }) : occurredAt = Value(occurredAt),
       dayStartDate = Value(dayStartDate),
       packageName = Value(packageName),
       eventType = Value(eventType),
       restrictionType = Value(restrictionType);
  static Insertable<RestrictedAccessEvent> custom({
    Expression<int>? id,
    Expression<int>? occurredAt,
    Expression<String>? dayStartDate,
    Expression<String>? packageName,
    Expression<int>? eventType,
    Expression<int>? restrictionType,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (dayStartDate != null) 'day_start_date': dayStartDate,
      if (packageName != null) 'package_name': packageName,
      if (eventType != null) 'event_type': eventType,
      if (restrictionType != null) 'restriction_type': restrictionType,
    });
  }

  RestrictedAccessEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? occurredAt,
    Value<String>? dayStartDate,
    Value<String>? packageName,
    Value<int>? eventType,
    Value<int>? restrictionType,
  }) {
    return RestrictedAccessEventsCompanion(
      id: id ?? this.id,
      occurredAt: occurredAt ?? this.occurredAt,
      dayStartDate: dayStartDate ?? this.dayStartDate,
      packageName: packageName ?? this.packageName,
      eventType: eventType ?? this.eventType,
      restrictionType: restrictionType ?? this.restrictionType,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (dayStartDate.present) {
      map['day_start_date'] = Variable<String>(dayStartDate.value);
    }
    if (packageName.present) {
      map['package_name'] = Variable<String>(packageName.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<int>(eventType.value);
    }
    if (restrictionType.present) {
      map['restriction_type'] = Variable<int>(restrictionType.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RestrictedAccessEventsCompanion(')
          ..write('id: $id, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('dayStartDate: $dayStartDate, ')
          ..write('packageName: $packageName, ')
          ..write('eventType: $eventType, ')
          ..write('restrictionType: $restrictionType')
          ..write(')'))
        .toString();
  }
}

class $IntentionUsageEventsTable extends IntentionUsageEvents
    with TableInfo<$IntentionUsageEventsTable, IntentionUsageEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IntentionUsageEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayStartDateMeta = const VerificationMeta(
    'dayStartDate',
  );
  @override
  late final GeneratedColumn<String> dayStartDate = GeneratedColumn<String>(
    'day_start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packageNameMeta = const VerificationMeta(
    'packageName',
  );
  @override
  late final GeneratedColumn<String> packageName = GeneratedColumn<String>(
    'package_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intentionNameMeta = const VerificationMeta(
    'intentionName',
  );
  @override
  late final GeneratedColumn<String> intentionName = GeneratedColumn<String>(
    'intention_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    occurredAt,
    dayStartDate,
    packageName,
    intentionName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'intention_usage_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<IntentionUsageEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('day_start_date')) {
      context.handle(
        _dayStartDateMeta,
        dayStartDate.isAcceptableOrUnknown(
          data['day_start_date']!,
          _dayStartDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dayStartDateMeta);
    }
    if (data.containsKey('package_name')) {
      context.handle(
        _packageNameMeta,
        packageName.isAcceptableOrUnknown(
          data['package_name']!,
          _packageNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_packageNameMeta);
    }
    if (data.containsKey('intention_name')) {
      context.handle(
        _intentionNameMeta,
        intentionName.isAcceptableOrUnknown(
          data['intention_name']!,
          _intentionNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_intentionNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IntentionUsageEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IntentionUsageEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at'],
      )!,
      dayStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_start_date'],
      )!,
      packageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_name'],
      )!,
      intentionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intention_name'],
      )!,
    );
  }

  @override
  $IntentionUsageEventsTable createAlias(String alias) {
    return $IntentionUsageEventsTable(attachedDatabase, alias);
  }
}

class IntentionUsageEvent extends DataClass
    implements Insertable<IntentionUsageEvent> {
  final int id;
  final int occurredAt;
  final String dayStartDate;
  final String packageName;
  final String intentionName;
  const IntentionUsageEvent({
    required this.id,
    required this.occurredAt,
    required this.dayStartDate,
    required this.packageName,
    required this.intentionName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['occurred_at'] = Variable<int>(occurredAt);
    map['day_start_date'] = Variable<String>(dayStartDate);
    map['package_name'] = Variable<String>(packageName);
    map['intention_name'] = Variable<String>(intentionName);
    return map;
  }

  IntentionUsageEventsCompanion toCompanion(bool nullToAbsent) {
    return IntentionUsageEventsCompanion(
      id: Value(id),
      occurredAt: Value(occurredAt),
      dayStartDate: Value(dayStartDate),
      packageName: Value(packageName),
      intentionName: Value(intentionName),
    );
  }

  factory IntentionUsageEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IntentionUsageEvent(
      id: serializer.fromJson<int>(json['id']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
      dayStartDate: serializer.fromJson<String>(json['dayStartDate']),
      packageName: serializer.fromJson<String>(json['packageName']),
      intentionName: serializer.fromJson<String>(json['intentionName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'occurredAt': serializer.toJson<int>(occurredAt),
      'dayStartDate': serializer.toJson<String>(dayStartDate),
      'packageName': serializer.toJson<String>(packageName),
      'intentionName': serializer.toJson<String>(intentionName),
    };
  }

  IntentionUsageEvent copyWith({
    int? id,
    int? occurredAt,
    String? dayStartDate,
    String? packageName,
    String? intentionName,
  }) => IntentionUsageEvent(
    id: id ?? this.id,
    occurredAt: occurredAt ?? this.occurredAt,
    dayStartDate: dayStartDate ?? this.dayStartDate,
    packageName: packageName ?? this.packageName,
    intentionName: intentionName ?? this.intentionName,
  );
  IntentionUsageEvent copyWithCompanion(IntentionUsageEventsCompanion data) {
    return IntentionUsageEvent(
      id: data.id.present ? data.id.value : this.id,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      dayStartDate: data.dayStartDate.present
          ? data.dayStartDate.value
          : this.dayStartDate,
      packageName: data.packageName.present
          ? data.packageName.value
          : this.packageName,
      intentionName: data.intentionName.present
          ? data.intentionName.value
          : this.intentionName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IntentionUsageEvent(')
          ..write('id: $id, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('dayStartDate: $dayStartDate, ')
          ..write('packageName: $packageName, ')
          ..write('intentionName: $intentionName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, occurredAt, dayStartDate, packageName, intentionName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntentionUsageEvent &&
          other.id == this.id &&
          other.occurredAt == this.occurredAt &&
          other.dayStartDate == this.dayStartDate &&
          other.packageName == this.packageName &&
          other.intentionName == this.intentionName);
}

class IntentionUsageEventsCompanion
    extends UpdateCompanion<IntentionUsageEvent> {
  final Value<int> id;
  final Value<int> occurredAt;
  final Value<String> dayStartDate;
  final Value<String> packageName;
  final Value<String> intentionName;
  const IntentionUsageEventsCompanion({
    this.id = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.dayStartDate = const Value.absent(),
    this.packageName = const Value.absent(),
    this.intentionName = const Value.absent(),
  });
  IntentionUsageEventsCompanion.insert({
    this.id = const Value.absent(),
    required int occurredAt,
    required String dayStartDate,
    required String packageName,
    required String intentionName,
  }) : occurredAt = Value(occurredAt),
       dayStartDate = Value(dayStartDate),
       packageName = Value(packageName),
       intentionName = Value(intentionName);
  static Insertable<IntentionUsageEvent> custom({
    Expression<int>? id,
    Expression<int>? occurredAt,
    Expression<String>? dayStartDate,
    Expression<String>? packageName,
    Expression<String>? intentionName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (dayStartDate != null) 'day_start_date': dayStartDate,
      if (packageName != null) 'package_name': packageName,
      if (intentionName != null) 'intention_name': intentionName,
    });
  }

  IntentionUsageEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? occurredAt,
    Value<String>? dayStartDate,
    Value<String>? packageName,
    Value<String>? intentionName,
  }) {
    return IntentionUsageEventsCompanion(
      id: id ?? this.id,
      occurredAt: occurredAt ?? this.occurredAt,
      dayStartDate: dayStartDate ?? this.dayStartDate,
      packageName: packageName ?? this.packageName,
      intentionName: intentionName ?? this.intentionName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (dayStartDate.present) {
      map['day_start_date'] = Variable<String>(dayStartDate.value);
    }
    if (packageName.present) {
      map['package_name'] = Variable<String>(packageName.value);
    }
    if (intentionName.present) {
      map['intention_name'] = Variable<String>(intentionName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IntentionUsageEventsCompanion(')
          ..write('id: $id, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('dayStartDate: $dayStartDate, ')
          ..write('packageName: $packageName, ')
          ..write('intentionName: $intentionName')
          ..write(')'))
        .toString();
  }
}

class $FocusUsageEventsTable extends FocusUsageEvents
    with TableInfo<$FocusUsageEventsTable, FocusUsageEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusUsageEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayStartDateMeta = const VerificationMeta(
    'dayStartDate',
  );
  @override
  late final GeneratedColumn<String> dayStartDate = GeneratedColumn<String>(
    'day_start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationInMsMeta = const VerificationMeta(
    'durationInMs',
  );
  @override
  late final GeneratedColumn<int> durationInMs = GeneratedColumn<int>(
    'duration_in_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    occurredAt,
    dayStartDate,
    durationInMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_usage_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<FocusUsageEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('day_start_date')) {
      context.handle(
        _dayStartDateMeta,
        dayStartDate.isAcceptableOrUnknown(
          data['day_start_date']!,
          _dayStartDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dayStartDateMeta);
    }
    if (data.containsKey('duration_in_ms')) {
      context.handle(
        _durationInMsMeta,
        durationInMs.isAcceptableOrUnknown(
          data['duration_in_ms']!,
          _durationInMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationInMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusUsageEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusUsageEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at'],
      )!,
      dayStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_start_date'],
      )!,
      durationInMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_in_ms'],
      )!,
    );
  }

  @override
  $FocusUsageEventsTable createAlias(String alias) {
    return $FocusUsageEventsTable(attachedDatabase, alias);
  }
}

class FocusUsageEvent extends DataClass implements Insertable<FocusUsageEvent> {
  final int id;
  final int occurredAt;
  final String dayStartDate;
  final int durationInMs;
  const FocusUsageEvent({
    required this.id,
    required this.occurredAt,
    required this.dayStartDate,
    required this.durationInMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['occurred_at'] = Variable<int>(occurredAt);
    map['day_start_date'] = Variable<String>(dayStartDate);
    map['duration_in_ms'] = Variable<int>(durationInMs);
    return map;
  }

  FocusUsageEventsCompanion toCompanion(bool nullToAbsent) {
    return FocusUsageEventsCompanion(
      id: Value(id),
      occurredAt: Value(occurredAt),
      dayStartDate: Value(dayStartDate),
      durationInMs: Value(durationInMs),
    );
  }

  factory FocusUsageEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusUsageEvent(
      id: serializer.fromJson<int>(json['id']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
      dayStartDate: serializer.fromJson<String>(json['dayStartDate']),
      durationInMs: serializer.fromJson<int>(json['durationInMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'occurredAt': serializer.toJson<int>(occurredAt),
      'dayStartDate': serializer.toJson<String>(dayStartDate),
      'durationInMs': serializer.toJson<int>(durationInMs),
    };
  }

  FocusUsageEvent copyWith({
    int? id,
    int? occurredAt,
    String? dayStartDate,
    int? durationInMs,
  }) => FocusUsageEvent(
    id: id ?? this.id,
    occurredAt: occurredAt ?? this.occurredAt,
    dayStartDate: dayStartDate ?? this.dayStartDate,
    durationInMs: durationInMs ?? this.durationInMs,
  );
  FocusUsageEvent copyWithCompanion(FocusUsageEventsCompanion data) {
    return FocusUsageEvent(
      id: data.id.present ? data.id.value : this.id,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      dayStartDate: data.dayStartDate.present
          ? data.dayStartDate.value
          : this.dayStartDate,
      durationInMs: data.durationInMs.present
          ? data.durationInMs.value
          : this.durationInMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusUsageEvent(')
          ..write('id: $id, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('dayStartDate: $dayStartDate, ')
          ..write('durationInMs: $durationInMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, occurredAt, dayStartDate, durationInMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusUsageEvent &&
          other.id == this.id &&
          other.occurredAt == this.occurredAt &&
          other.dayStartDate == this.dayStartDate &&
          other.durationInMs == this.durationInMs);
}

class FocusUsageEventsCompanion extends UpdateCompanion<FocusUsageEvent> {
  final Value<int> id;
  final Value<int> occurredAt;
  final Value<String> dayStartDate;
  final Value<int> durationInMs;
  const FocusUsageEventsCompanion({
    this.id = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.dayStartDate = const Value.absent(),
    this.durationInMs = const Value.absent(),
  });
  FocusUsageEventsCompanion.insert({
    this.id = const Value.absent(),
    required int occurredAt,
    required String dayStartDate,
    required int durationInMs,
  }) : occurredAt = Value(occurredAt),
       dayStartDate = Value(dayStartDate),
       durationInMs = Value(durationInMs);
  static Insertable<FocusUsageEvent> custom({
    Expression<int>? id,
    Expression<int>? occurredAt,
    Expression<String>? dayStartDate,
    Expression<int>? durationInMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (dayStartDate != null) 'day_start_date': dayStartDate,
      if (durationInMs != null) 'duration_in_ms': durationInMs,
    });
  }

  FocusUsageEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? occurredAt,
    Value<String>? dayStartDate,
    Value<int>? durationInMs,
  }) {
    return FocusUsageEventsCompanion(
      id: id ?? this.id,
      occurredAt: occurredAt ?? this.occurredAt,
      dayStartDate: dayStartDate ?? this.dayStartDate,
      durationInMs: durationInMs ?? this.durationInMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (dayStartDate.present) {
      map['day_start_date'] = Variable<String>(dayStartDate.value);
    }
    if (durationInMs.present) {
      map['duration_in_ms'] = Variable<int>(durationInMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusUsageEventsCompanion(')
          ..write('id: $id, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('dayStartDate: $dayStartDate, ')
          ..write('durationInMs: $durationInMs')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, Favorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _packageNameMeta = const VerificationMeta(
    'packageName',
  );
  @override
  late final GeneratedColumn<String> packageName = GeneratedColumn<String>(
    'package_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES applications (package_name) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, packageName, orderIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<Favorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('package_name')) {
      context.handle(
        _packageNameMeta,
        packageName.isAcceptableOrUnknown(
          data['package_name']!,
          _packageNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_packageNameMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {packageName},
  ];
  @override
  Favorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Favorite(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      packageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_name'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class Favorite extends DataClass implements Insertable<Favorite> {
  final int id;
  final String packageName;
  final int orderIndex;
  const Favorite({
    required this.id,
    required this.packageName,
    required this.orderIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['package_name'] = Variable<String>(packageName);
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      id: Value(id),
      packageName: Value(packageName),
      orderIndex: Value(orderIndex),
    );
  }

  factory Favorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Favorite(
      id: serializer.fromJson<int>(json['id']),
      packageName: serializer.fromJson<String>(json['packageName']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'packageName': serializer.toJson<String>(packageName),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  Favorite copyWith({int? id, String? packageName, int? orderIndex}) =>
      Favorite(
        id: id ?? this.id,
        packageName: packageName ?? this.packageName,
        orderIndex: orderIndex ?? this.orderIndex,
      );
  Favorite copyWithCompanion(FavoritesCompanion data) {
    return Favorite(
      id: data.id.present ? data.id.value : this.id,
      packageName: data.packageName.present
          ? data.packageName.value
          : this.packageName,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Favorite(')
          ..write('id: $id, ')
          ..write('packageName: $packageName, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, packageName, orderIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Favorite &&
          other.id == this.id &&
          other.packageName == this.packageName &&
          other.orderIndex == this.orderIndex);
}

class FavoritesCompanion extends UpdateCompanion<Favorite> {
  final Value<int> id;
  final Value<String> packageName;
  final Value<int> orderIndex;
  const FavoritesCompanion({
    this.id = const Value.absent(),
    this.packageName = const Value.absent(),
    this.orderIndex = const Value.absent(),
  });
  FavoritesCompanion.insert({
    this.id = const Value.absent(),
    required String packageName,
    required int orderIndex,
  }) : packageName = Value(packageName),
       orderIndex = Value(orderIndex);
  static Insertable<Favorite> custom({
    Expression<int>? id,
    Expression<String>? packageName,
    Expression<int>? orderIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (packageName != null) 'package_name': packageName,
      if (orderIndex != null) 'order_index': orderIndex,
    });
  }

  FavoritesCompanion copyWith({
    Value<int>? id,
    Value<String>? packageName,
    Value<int>? orderIndex,
  }) {
    return FavoritesCompanion(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (packageName.present) {
      map['package_name'] = Variable<String>(packageName.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('id: $id, ')
          ..write('packageName: $packageName, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }
}

class $AchievementsUnlockedTable extends AchievementsUnlocked
    with TableInfo<$AchievementsUnlockedTable, AchievementsUnlockedData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AchievementsUnlockedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unlockedAtMeta = const VerificationMeta(
    'unlockedAt',
  );
  @override
  late final GeneratedColumn<int> unlockedAt = GeneratedColumn<int>(
    'unlocked_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, unlockedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'achievements_unlocked';
  @override
  VerificationContext validateIntegrity(
    Insertable<AchievementsUnlockedData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('unlocked_at')) {
      context.handle(
        _unlockedAtMeta,
        unlockedAt.isAcceptableOrUnknown(data['unlocked_at']!, _unlockedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_unlockedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AchievementsUnlockedData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AchievementsUnlockedData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      unlockedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unlocked_at'],
      )!,
    );
  }

  @override
  $AchievementsUnlockedTable createAlias(String alias) {
    return $AchievementsUnlockedTable(attachedDatabase, alias);
  }
}

class AchievementsUnlockedData extends DataClass
    implements Insertable<AchievementsUnlockedData> {
  final String id;
  final int unlockedAt;
  const AchievementsUnlockedData({required this.id, required this.unlockedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['unlocked_at'] = Variable<int>(unlockedAt);
    return map;
  }

  AchievementsUnlockedCompanion toCompanion(bool nullToAbsent) {
    return AchievementsUnlockedCompanion(
      id: Value(id),
      unlockedAt: Value(unlockedAt),
    );
  }

  factory AchievementsUnlockedData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AchievementsUnlockedData(
      id: serializer.fromJson<String>(json['id']),
      unlockedAt: serializer.fromJson<int>(json['unlockedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'unlockedAt': serializer.toJson<int>(unlockedAt),
    };
  }

  AchievementsUnlockedData copyWith({String? id, int? unlockedAt}) =>
      AchievementsUnlockedData(
        id: id ?? this.id,
        unlockedAt: unlockedAt ?? this.unlockedAt,
      );
  AchievementsUnlockedData copyWithCompanion(
    AchievementsUnlockedCompanion data,
  ) {
    return AchievementsUnlockedData(
      id: data.id.present ? data.id.value : this.id,
      unlockedAt: data.unlockedAt.present
          ? data.unlockedAt.value
          : this.unlockedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AchievementsUnlockedData(')
          ..write('id: $id, ')
          ..write('unlockedAt: $unlockedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, unlockedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AchievementsUnlockedData &&
          other.id == this.id &&
          other.unlockedAt == this.unlockedAt);
}

class AchievementsUnlockedCompanion
    extends UpdateCompanion<AchievementsUnlockedData> {
  final Value<String> id;
  final Value<int> unlockedAt;
  final Value<int> rowid;
  const AchievementsUnlockedCompanion({
    this.id = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AchievementsUnlockedCompanion.insert({
    required String id,
    required int unlockedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       unlockedAt = Value(unlockedAt);
  static Insertable<AchievementsUnlockedData> custom({
    Expression<String>? id,
    Expression<int>? unlockedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (unlockedAt != null) 'unlocked_at': unlockedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AchievementsUnlockedCompanion copyWith({
    Value<String>? id,
    Value<int>? unlockedAt,
    Value<int>? rowid,
  }) {
    return AchievementsUnlockedCompanion(
      id: id ?? this.id,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (unlockedAt.present) {
      map['unlocked_at'] = Variable<int>(unlockedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AchievementsUnlockedCompanion(')
          ..write('id: $id, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StreakStateTable extends StreakState
    with TableInfo<$StreakStateTable, StreakStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StreakStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentCountMeta = const VerificationMeta(
    'currentCount',
  );
  @override
  late final GeneratedColumn<int> currentCount = GeneratedColumn<int>(
    'current_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _longestMeta = const VerificationMeta(
    'longest',
  );
  @override
  late final GeneratedColumn<int> longest = GeneratedColumn<int>(
    'longest',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastIncrementedDayMeta =
      const VerificationMeta('lastIncrementedDay');
  @override
  late final GeneratedColumn<String> lastIncrementedDay =
      GeneratedColumn<String>(
        'last_incremented_day',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    currentCount,
    longest,
    lastIncrementedDay,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'streak_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<StreakStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('current_count')) {
      context.handle(
        _currentCountMeta,
        currentCount.isAcceptableOrUnknown(
          data['current_count']!,
          _currentCountMeta,
        ),
      );
    }
    if (data.containsKey('longest')) {
      context.handle(
        _longestMeta,
        longest.isAcceptableOrUnknown(data['longest']!, _longestMeta),
      );
    }
    if (data.containsKey('last_incremented_day')) {
      context.handle(
        _lastIncrementedDayMeta,
        lastIncrementedDay.isAcceptableOrUnknown(
          data['last_incremented_day']!,
          _lastIncrementedDayMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StreakStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StreakStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      currentCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_count'],
      )!,
      longest: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}longest'],
      )!,
      lastIncrementedDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_incremented_day'],
      ),
    );
  }

  @override
  $StreakStateTable createAlias(String alias) {
    return $StreakStateTable(attachedDatabase, alias);
  }
}

class StreakStateData extends DataClass implements Insertable<StreakStateData> {
  final String id;
  final int currentCount;
  final int longest;
  final String? lastIncrementedDay;
  const StreakStateData({
    required this.id,
    required this.currentCount,
    required this.longest,
    this.lastIncrementedDay,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['current_count'] = Variable<int>(currentCount);
    map['longest'] = Variable<int>(longest);
    if (!nullToAbsent || lastIncrementedDay != null) {
      map['last_incremented_day'] = Variable<String>(lastIncrementedDay);
    }
    return map;
  }

  StreakStateCompanion toCompanion(bool nullToAbsent) {
    return StreakStateCompanion(
      id: Value(id),
      currentCount: Value(currentCount),
      longest: Value(longest),
      lastIncrementedDay: lastIncrementedDay == null && nullToAbsent
          ? const Value.absent()
          : Value(lastIncrementedDay),
    );
  }

  factory StreakStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StreakStateData(
      id: serializer.fromJson<String>(json['id']),
      currentCount: serializer.fromJson<int>(json['currentCount']),
      longest: serializer.fromJson<int>(json['longest']),
      lastIncrementedDay: serializer.fromJson<String?>(
        json['lastIncrementedDay'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'currentCount': serializer.toJson<int>(currentCount),
      'longest': serializer.toJson<int>(longest),
      'lastIncrementedDay': serializer.toJson<String?>(lastIncrementedDay),
    };
  }

  StreakStateData copyWith({
    String? id,
    int? currentCount,
    int? longest,
    Value<String?> lastIncrementedDay = const Value.absent(),
  }) => StreakStateData(
    id: id ?? this.id,
    currentCount: currentCount ?? this.currentCount,
    longest: longest ?? this.longest,
    lastIncrementedDay: lastIncrementedDay.present
        ? lastIncrementedDay.value
        : this.lastIncrementedDay,
  );
  StreakStateData copyWithCompanion(StreakStateCompanion data) {
    return StreakStateData(
      id: data.id.present ? data.id.value : this.id,
      currentCount: data.currentCount.present
          ? data.currentCount.value
          : this.currentCount,
      longest: data.longest.present ? data.longest.value : this.longest,
      lastIncrementedDay: data.lastIncrementedDay.present
          ? data.lastIncrementedDay.value
          : this.lastIncrementedDay,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StreakStateData(')
          ..write('id: $id, ')
          ..write('currentCount: $currentCount, ')
          ..write('longest: $longest, ')
          ..write('lastIncrementedDay: $lastIncrementedDay')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, currentCount, longest, lastIncrementedDay);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StreakStateData &&
          other.id == this.id &&
          other.currentCount == this.currentCount &&
          other.longest == this.longest &&
          other.lastIncrementedDay == this.lastIncrementedDay);
}

class StreakStateCompanion extends UpdateCompanion<StreakStateData> {
  final Value<String> id;
  final Value<int> currentCount;
  final Value<int> longest;
  final Value<String?> lastIncrementedDay;
  final Value<int> rowid;
  const StreakStateCompanion({
    this.id = const Value.absent(),
    this.currentCount = const Value.absent(),
    this.longest = const Value.absent(),
    this.lastIncrementedDay = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StreakStateCompanion.insert({
    required String id,
    this.currentCount = const Value.absent(),
    this.longest = const Value.absent(),
    this.lastIncrementedDay = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<StreakStateData> custom({
    Expression<String>? id,
    Expression<int>? currentCount,
    Expression<int>? longest,
    Expression<String>? lastIncrementedDay,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currentCount != null) 'current_count': currentCount,
      if (longest != null) 'longest': longest,
      if (lastIncrementedDay != null)
        'last_incremented_day': lastIncrementedDay,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StreakStateCompanion copyWith({
    Value<String>? id,
    Value<int>? currentCount,
    Value<int>? longest,
    Value<String?>? lastIncrementedDay,
    Value<int>? rowid,
  }) {
    return StreakStateCompanion(
      id: id ?? this.id,
      currentCount: currentCount ?? this.currentCount,
      longest: longest ?? this.longest,
      lastIncrementedDay: lastIncrementedDay ?? this.lastIncrementedDay,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (currentCount.present) {
      map['current_count'] = Variable<int>(currentCount.value);
    }
    if (longest.present) {
      map['longest'] = Variable<int>(longest.value);
    }
    if (lastIncrementedDay.present) {
      map['last_incremented_day'] = Variable<String>(lastIncrementedDay.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StreakStateCompanion(')
          ..write('id: $id, ')
          ..write('currentCount: $currentCount, ')
          ..write('longest: $longest, ')
          ..write('lastIncrementedDay: $lastIncrementedDay, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalEntriesTable extends JournalEntries
    with TableInfo<$JournalEntriesTable, JournalEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayStartDateMeta = const VerificationMeta(
    'dayStartDate',
  );
  @override
  late final GeneratedColumn<String> dayStartDate = GeneratedColumn<String>(
    'day_start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    dayStartDate,
    createdAt,
    updatedAt,
    body,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<JournalEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day_start_date')) {
      context.handle(
        _dayStartDateMeta,
        dayStartDate.isAcceptableOrUnknown(
          data['day_start_date']!,
          _dayStartDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dayStartDateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dayStartDate};
  @override
  JournalEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalEntry(
      dayStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_start_date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
    );
  }

  @override
  $JournalEntriesTable createAlias(String alias) {
    return $JournalEntriesTable(attachedDatabase, alias);
  }
}

class JournalEntry extends DataClass implements Insertable<JournalEntry> {
  final String dayStartDate;
  final int createdAt;
  final int updatedAt;
  final String body;
  const JournalEntry({
    required this.dayStartDate,
    required this.createdAt,
    required this.updatedAt,
    required this.body,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day_start_date'] = Variable<String>(dayStartDate);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['body'] = Variable<String>(body);
    return map;
  }

  JournalEntriesCompanion toCompanion(bool nullToAbsent) {
    return JournalEntriesCompanion(
      dayStartDate: Value(dayStartDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      body: Value(body),
    );
  }

  factory JournalEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalEntry(
      dayStartDate: serializer.fromJson<String>(json['dayStartDate']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      body: serializer.fromJson<String>(json['body']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dayStartDate': serializer.toJson<String>(dayStartDate),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'body': serializer.toJson<String>(body),
    };
  }

  JournalEntry copyWith({
    String? dayStartDate,
    int? createdAt,
    int? updatedAt,
    String? body,
  }) => JournalEntry(
    dayStartDate: dayStartDate ?? this.dayStartDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    body: body ?? this.body,
  );
  JournalEntry copyWithCompanion(JournalEntriesCompanion data) {
    return JournalEntry(
      dayStartDate: data.dayStartDate.present
          ? data.dayStartDate.value
          : this.dayStartDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      body: data.body.present ? data.body.value : this.body,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntry(')
          ..write('dayStartDate: $dayStartDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dayStartDate, createdAt, updatedAt, body);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalEntry &&
          other.dayStartDate == this.dayStartDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.body == this.body);
}

class JournalEntriesCompanion extends UpdateCompanion<JournalEntry> {
  final Value<String> dayStartDate;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> body;
  final Value<int> rowid;
  const JournalEntriesCompanion({
    this.dayStartDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.body = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalEntriesCompanion.insert({
    required String dayStartDate,
    required int createdAt,
    required int updatedAt,
    required String body,
    this.rowid = const Value.absent(),
  }) : dayStartDate = Value(dayStartDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       body = Value(body);
  static Insertable<JournalEntry> custom({
    Expression<String>? dayStartDate,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? body,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dayStartDate != null) 'day_start_date': dayStartDate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (body != null) 'body': body,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalEntriesCompanion copyWith({
    Value<String>? dayStartDate,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? body,
    Value<int>? rowid,
  }) {
    return JournalEntriesCompanion(
      dayStartDate: dayStartDate ?? this.dayStartDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      body: body ?? this.body,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dayStartDate.present) {
      map['day_start_date'] = Variable<String>(dayStartDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntriesCompanion(')
          ..write('dayStartDate: $dayStartDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('body: $body, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $ApplicationsTable applications = $ApplicationsTable(this);
  late final $AppProfileRelationsTable appProfileRelations =
      $AppProfileRelationsTable(this);
  late final $WebsiteRulesTable websiteRules = $WebsiteRulesTable(this);
  late final $IntervalsTable intervals = $IntervalsTable(this);
  late final $UsageLimitsTable usageLimits = $UsageLimitsTable(this);
  late final $GeoAddressesTable geoAddresses = $GeoAddressesTable(this);
  late final $WifiNetworksTable wifiNetworks = $WifiNetworksTable(this);
  late final $BlockSessionsTable blockSessions = $BlockSessionsTable(this);
  late final $BrowserConfigsTable browserConfigs = $BrowserConfigsTable(this);
  late final $AdultContentSitesTable adultContentSites =
      $AdultContentSitesTable(this);
  late final $PomodoroSessionsTable pomodoroSessions = $PomodoroSessionsTable(
    this,
  );
  late final $BlockingConfigsTable blockingConfigs = $BlockingConfigsTable(
    this,
  );
  late final $MoodCheckInsTable moodCheckIns = $MoodCheckInsTable(this);
  late final $EmergencyUnblocksTable emergencyUnblocks =
      $EmergencyUnblocksTable(this);
  late final $UsedBackdoorCodesTable usedBackdoorCodes =
      $UsedBackdoorCodesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $RestrictedAccessEventsTable restrictedAccessEvents =
      $RestrictedAccessEventsTable(this);
  late final $IntentionUsageEventsTable intentionUsageEvents =
      $IntentionUsageEventsTable(this);
  late final $FocusUsageEventsTable focusUsageEvents = $FocusUsageEventsTable(
    this,
  );
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $AchievementsUnlockedTable achievementsUnlocked =
      $AchievementsUnlockedTable(this);
  late final $StreakStateTable streakState = $StreakStateTable(this);
  late final $JournalEntriesTable journalEntries = $JournalEntriesTable(this);
  late final RestrictedAccessEventsDao restrictedAccessEventsDao =
      RestrictedAccessEventsDao(this as AppDatabase);
  late final IntentionUsageEventsDao intentionUsageEventsDao =
      IntentionUsageEventsDao(this as AppDatabase);
  late final FocusUsageEventsDao focusUsageEventsDao = FocusUsageEventsDao(
    this as AppDatabase,
  );
  late final AchievementsDao achievementsDao = AchievementsDao(
    this as AppDatabase,
  );
  late final StreaksDao streaksDao = StreaksDao(this as AppDatabase);
  late final JournalDao journalDao = JournalDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    profiles,
    applications,
    appProfileRelations,
    websiteRules,
    intervals,
    usageLimits,
    geoAddresses,
    wifiNetworks,
    blockSessions,
    browserConfigs,
    adultContentSites,
    pomodoroSessions,
    blockingConfigs,
    moodCheckIns,
    emergencyUnblocks,
    usedBackdoorCodes,
    settings,
    restrictedAccessEvents,
    intentionUsageEvents,
    focusUsageEvents,
    favorites,
    achievementsUnlocked,
    streakState,
    journalEntries,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'applications',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('favorites', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ProfilesTableCreateCompanionBuilder =
    ProfilesCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<int> typeCombinations,
      Value<int> onConditions,
      Value<int> operator,
      Value<int> dayFlags,
      Value<bool> blockNotifications,
      Value<bool> blockLaunch,
      Value<bool> addNewApplications,
      Value<bool> isEnabled,
      Value<bool> isLocked,
      Value<int> lastStartTime,
      Value<int> onUntil,
      Value<int> lockedUntil,
      Value<int> lockAt,
      Value<int> pausedUntil,
      Value<int> blockingMode,
      Value<String> emoji,
      Value<bool> blockUnsupportedBrowsers,
      Value<bool> blockAdultContent,
      Value<int> sortOrder,
      Value<String> colorHex,
      Value<int?> presetId,
    });
typedef $$ProfilesTableUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<int> typeCombinations,
      Value<int> onConditions,
      Value<int> operator,
      Value<int> dayFlags,
      Value<bool> blockNotifications,
      Value<bool> blockLaunch,
      Value<bool> addNewApplications,
      Value<bool> isEnabled,
      Value<bool> isLocked,
      Value<int> lastStartTime,
      Value<int> onUntil,
      Value<int> lockedUntil,
      Value<int> lockAt,
      Value<int> pausedUntil,
      Value<int> blockingMode,
      Value<String> emoji,
      Value<bool> blockUnsupportedBrowsers,
      Value<bool> blockAdultContent,
      Value<int> sortOrder,
      Value<String> colorHex,
      Value<int?> presetId,
    });

final class $$ProfilesTableReferences
    extends BaseReferences<_$AppDatabase, $ProfilesTable, Profile> {
  $$ProfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $AppProfileRelationsTable,
    List<AppProfileRelation>
  >
  _appProfileRelationsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.appProfileRelations,
        aliasName: $_aliasNameGenerator(
          db.profiles.id,
          db.appProfileRelations.profileId,
        ),
      );

  $$AppProfileRelationsTableProcessedTableManager get appProfileRelationsRefs {
    final manager = $$AppProfileRelationsTableTableManager(
      $_db,
      $_db.appProfileRelations,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _appProfileRelationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WebsiteRulesTable, List<WebsiteRule>>
  _websiteRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.websiteRules,
    aliasName: $_aliasNameGenerator(db.profiles.id, db.websiteRules.profileId),
  );

  $$WebsiteRulesTableProcessedTableManager get websiteRulesRefs {
    final manager = $$WebsiteRulesTableTableManager(
      $_db,
      $_db.websiteRules,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_websiteRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$IntervalsTable, List<Interval>>
  _intervalsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.intervals,
    aliasName: $_aliasNameGenerator(db.profiles.id, db.intervals.profileId),
  );

  $$IntervalsTableProcessedTableManager get intervalsRefs {
    final manager = $$IntervalsTableTableManager(
      $_db,
      $_db.intervals,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_intervalsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UsageLimitsTable, List<UsageLimit>>
  _usageLimitsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.usageLimits,
    aliasName: $_aliasNameGenerator(db.profiles.id, db.usageLimits.profileId),
  );

  $$UsageLimitsTableProcessedTableManager get usageLimitsRefs {
    final manager = $$UsageLimitsTableTableManager(
      $_db,
      $_db.usageLimits,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_usageLimitsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GeoAddressesTable, List<GeoAddressesData>>
  _geoAddressesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.geoAddresses,
    aliasName: $_aliasNameGenerator(db.profiles.id, db.geoAddresses.profileId),
  );

  $$GeoAddressesTableProcessedTableManager get geoAddressesRefs {
    final manager = $$GeoAddressesTableTableManager(
      $_db,
      $_db.geoAddresses,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_geoAddressesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WifiNetworksTable, List<WifiNetwork>>
  _wifiNetworksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.wifiNetworks,
    aliasName: $_aliasNameGenerator(db.profiles.id, db.wifiNetworks.profileId),
  );

  $$WifiNetworksTableProcessedTableManager get wifiNetworksRefs {
    final manager = $$WifiNetworksTableTableManager(
      $_db,
      $_db.wifiNetworks,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_wifiNetworksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get typeCombinations => $composableBuilder(
    column: $table.typeCombinations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get onConditions => $composableBuilder(
    column: $table.onConditions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get operator => $composableBuilder(
    column: $table.operator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayFlags => $composableBuilder(
    column: $table.dayFlags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get blockNotifications => $composableBuilder(
    column: $table.blockNotifications,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get blockLaunch => $composableBuilder(
    column: $table.blockLaunch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get addNewApplications => $composableBuilder(
    column: $table.addNewApplications,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastStartTime => $composableBuilder(
    column: $table.lastStartTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get onUntil => $composableBuilder(
    column: $table.onUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lockedUntil => $composableBuilder(
    column: $table.lockedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lockAt => $composableBuilder(
    column: $table.lockAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pausedUntil => $composableBuilder(
    column: $table.pausedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blockingMode => $composableBuilder(
    column: $table.blockingMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get blockUnsupportedBrowsers => $composableBuilder(
    column: $table.blockUnsupportedBrowsers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get blockAdultContent => $composableBuilder(
    column: $table.blockAdultContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get presetId => $composableBuilder(
    column: $table.presetId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> appProfileRelationsRefs(
    Expression<bool> Function($$AppProfileRelationsTableFilterComposer f) f,
  ) {
    final $$AppProfileRelationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.appProfileRelations,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppProfileRelationsTableFilterComposer(
            $db: $db,
            $table: $db.appProfileRelations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> websiteRulesRefs(
    Expression<bool> Function($$WebsiteRulesTableFilterComposer f) f,
  ) {
    final $$WebsiteRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.websiteRules,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WebsiteRulesTableFilterComposer(
            $db: $db,
            $table: $db.websiteRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> intervalsRefs(
    Expression<bool> Function($$IntervalsTableFilterComposer f) f,
  ) {
    final $$IntervalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.intervals,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntervalsTableFilterComposer(
            $db: $db,
            $table: $db.intervals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> usageLimitsRefs(
    Expression<bool> Function($$UsageLimitsTableFilterComposer f) f,
  ) {
    final $$UsageLimitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.usageLimits,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsageLimitsTableFilterComposer(
            $db: $db,
            $table: $db.usageLimits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> geoAddressesRefs(
    Expression<bool> Function($$GeoAddressesTableFilterComposer f) f,
  ) {
    final $$GeoAddressesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.geoAddresses,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GeoAddressesTableFilterComposer(
            $db: $db,
            $table: $db.geoAddresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> wifiNetworksRefs(
    Expression<bool> Function($$WifiNetworksTableFilterComposer f) f,
  ) {
    final $$WifiNetworksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wifiNetworks,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WifiNetworksTableFilterComposer(
            $db: $db,
            $table: $db.wifiNetworks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get typeCombinations => $composableBuilder(
    column: $table.typeCombinations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get onConditions => $composableBuilder(
    column: $table.onConditions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get operator => $composableBuilder(
    column: $table.operator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayFlags => $composableBuilder(
    column: $table.dayFlags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get blockNotifications => $composableBuilder(
    column: $table.blockNotifications,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get blockLaunch => $composableBuilder(
    column: $table.blockLaunch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get addNewApplications => $composableBuilder(
    column: $table.addNewApplications,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastStartTime => $composableBuilder(
    column: $table.lastStartTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get onUntil => $composableBuilder(
    column: $table.onUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lockedUntil => $composableBuilder(
    column: $table.lockedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lockAt => $composableBuilder(
    column: $table.lockAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pausedUntil => $composableBuilder(
    column: $table.pausedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blockingMode => $composableBuilder(
    column: $table.blockingMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get blockUnsupportedBrowsers => $composableBuilder(
    column: $table.blockUnsupportedBrowsers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get blockAdultContent => $composableBuilder(
    column: $table.blockAdultContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get presetId => $composableBuilder(
    column: $table.presetId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get typeCombinations => $composableBuilder(
    column: $table.typeCombinations,
    builder: (column) => column,
  );

  GeneratedColumn<int> get onConditions => $composableBuilder(
    column: $table.onConditions,
    builder: (column) => column,
  );

  GeneratedColumn<int> get operator =>
      $composableBuilder(column: $table.operator, builder: (column) => column);

  GeneratedColumn<int> get dayFlags =>
      $composableBuilder(column: $table.dayFlags, builder: (column) => column);

  GeneratedColumn<bool> get blockNotifications => $composableBuilder(
    column: $table.blockNotifications,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get blockLaunch => $composableBuilder(
    column: $table.blockLaunch,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get addNewApplications => $composableBuilder(
    column: $table.addNewApplications,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<bool> get isLocked =>
      $composableBuilder(column: $table.isLocked, builder: (column) => column);

  GeneratedColumn<int> get lastStartTime => $composableBuilder(
    column: $table.lastStartTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get onUntil =>
      $composableBuilder(column: $table.onUntil, builder: (column) => column);

  GeneratedColumn<int> get lockedUntil => $composableBuilder(
    column: $table.lockedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lockAt =>
      $composableBuilder(column: $table.lockAt, builder: (column) => column);

  GeneratedColumn<int> get pausedUntil => $composableBuilder(
    column: $table.pausedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get blockingMode => $composableBuilder(
    column: $table.blockingMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<bool> get blockUnsupportedBrowsers => $composableBuilder(
    column: $table.blockUnsupportedBrowsers,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get blockAdultContent => $composableBuilder(
    column: $table.blockAdultContent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<int> get presetId =>
      $composableBuilder(column: $table.presetId, builder: (column) => column);

  Expression<T> appProfileRelationsRefs<T extends Object>(
    Expression<T> Function($$AppProfileRelationsTableAnnotationComposer a) f,
  ) {
    final $$AppProfileRelationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.appProfileRelations,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AppProfileRelationsTableAnnotationComposer(
                $db: $db,
                $table: $db.appProfileRelations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> websiteRulesRefs<T extends Object>(
    Expression<T> Function($$WebsiteRulesTableAnnotationComposer a) f,
  ) {
    final $$WebsiteRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.websiteRules,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WebsiteRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.websiteRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> intervalsRefs<T extends Object>(
    Expression<T> Function($$IntervalsTableAnnotationComposer a) f,
  ) {
    final $$IntervalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.intervals,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntervalsTableAnnotationComposer(
            $db: $db,
            $table: $db.intervals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> usageLimitsRefs<T extends Object>(
    Expression<T> Function($$UsageLimitsTableAnnotationComposer a) f,
  ) {
    final $$UsageLimitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.usageLimits,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsageLimitsTableAnnotationComposer(
            $db: $db,
            $table: $db.usageLimits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> geoAddressesRefs<T extends Object>(
    Expression<T> Function($$GeoAddressesTableAnnotationComposer a) f,
  ) {
    final $$GeoAddressesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.geoAddresses,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GeoAddressesTableAnnotationComposer(
            $db: $db,
            $table: $db.geoAddresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> wifiNetworksRefs<T extends Object>(
    Expression<T> Function($$WifiNetworksTableAnnotationComposer a) f,
  ) {
    final $$WifiNetworksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wifiNetworks,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WifiNetworksTableAnnotationComposer(
            $db: $db,
            $table: $db.wifiNetworks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfilesTable,
          Profile,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (Profile, $$ProfilesTableReferences),
          Profile,
          PrefetchHooks Function({
            bool appProfileRelationsRefs,
            bool websiteRulesRefs,
            bool intervalsRefs,
            bool usageLimitsRefs,
            bool geoAddressesRefs,
            bool wifiNetworksRefs,
          })
        > {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> typeCombinations = const Value.absent(),
                Value<int> onConditions = const Value.absent(),
                Value<int> operator = const Value.absent(),
                Value<int> dayFlags = const Value.absent(),
                Value<bool> blockNotifications = const Value.absent(),
                Value<bool> blockLaunch = const Value.absent(),
                Value<bool> addNewApplications = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<bool> isLocked = const Value.absent(),
                Value<int> lastStartTime = const Value.absent(),
                Value<int> onUntil = const Value.absent(),
                Value<int> lockedUntil = const Value.absent(),
                Value<int> lockAt = const Value.absent(),
                Value<int> pausedUntil = const Value.absent(),
                Value<int> blockingMode = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<bool> blockUnsupportedBrowsers = const Value.absent(),
                Value<bool> blockAdultContent = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<int?> presetId = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                title: title,
                typeCombinations: typeCombinations,
                onConditions: onConditions,
                operator: operator,
                dayFlags: dayFlags,
                blockNotifications: blockNotifications,
                blockLaunch: blockLaunch,
                addNewApplications: addNewApplications,
                isEnabled: isEnabled,
                isLocked: isLocked,
                lastStartTime: lastStartTime,
                onUntil: onUntil,
                lockedUntil: lockedUntil,
                lockAt: lockAt,
                pausedUntil: pausedUntil,
                blockingMode: blockingMode,
                emoji: emoji,
                blockUnsupportedBrowsers: blockUnsupportedBrowsers,
                blockAdultContent: blockAdultContent,
                sortOrder: sortOrder,
                colorHex: colorHex,
                presetId: presetId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> typeCombinations = const Value.absent(),
                Value<int> onConditions = const Value.absent(),
                Value<int> operator = const Value.absent(),
                Value<int> dayFlags = const Value.absent(),
                Value<bool> blockNotifications = const Value.absent(),
                Value<bool> blockLaunch = const Value.absent(),
                Value<bool> addNewApplications = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<bool> isLocked = const Value.absent(),
                Value<int> lastStartTime = const Value.absent(),
                Value<int> onUntil = const Value.absent(),
                Value<int> lockedUntil = const Value.absent(),
                Value<int> lockAt = const Value.absent(),
                Value<int> pausedUntil = const Value.absent(),
                Value<int> blockingMode = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<bool> blockUnsupportedBrowsers = const Value.absent(),
                Value<bool> blockAdultContent = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<int?> presetId = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                title: title,
                typeCombinations: typeCombinations,
                onConditions: onConditions,
                operator: operator,
                dayFlags: dayFlags,
                blockNotifications: blockNotifications,
                blockLaunch: blockLaunch,
                addNewApplications: addNewApplications,
                isEnabled: isEnabled,
                isLocked: isLocked,
                lastStartTime: lastStartTime,
                onUntil: onUntil,
                lockedUntil: lockedUntil,
                lockAt: lockAt,
                pausedUntil: pausedUntil,
                blockingMode: blockingMode,
                emoji: emoji,
                blockUnsupportedBrowsers: blockUnsupportedBrowsers,
                blockAdultContent: blockAdultContent,
                sortOrder: sortOrder,
                colorHex: colorHex,
                presetId: presetId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                appProfileRelationsRefs = false,
                websiteRulesRefs = false,
                intervalsRefs = false,
                usageLimitsRefs = false,
                geoAddressesRefs = false,
                wifiNetworksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (appProfileRelationsRefs) db.appProfileRelations,
                    if (websiteRulesRefs) db.websiteRules,
                    if (intervalsRefs) db.intervals,
                    if (usageLimitsRefs) db.usageLimits,
                    if (geoAddressesRefs) db.geoAddresses,
                    if (wifiNetworksRefs) db.wifiNetworks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (appProfileRelationsRefs)
                        await $_getPrefetchedData<
                          Profile,
                          $ProfilesTable,
                          AppProfileRelation
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._appProfileRelationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).appProfileRelationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (websiteRulesRefs)
                        await $_getPrefetchedData<
                          Profile,
                          $ProfilesTable,
                          WebsiteRule
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._websiteRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).websiteRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (intervalsRefs)
                        await $_getPrefetchedData<
                          Profile,
                          $ProfilesTable,
                          Interval
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._intervalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).intervalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (usageLimitsRefs)
                        await $_getPrefetchedData<
                          Profile,
                          $ProfilesTable,
                          UsageLimit
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._usageLimitsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).usageLimitsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (geoAddressesRefs)
                        await $_getPrefetchedData<
                          Profile,
                          $ProfilesTable,
                          GeoAddressesData
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._geoAddressesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).geoAddressesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (wifiNetworksRefs)
                        await $_getPrefetchedData<
                          Profile,
                          $ProfilesTable,
                          WifiNetwork
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._wifiNetworksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).wifiNetworksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfilesTable,
      Profile,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (Profile, $$ProfilesTableReferences),
      Profile,
      PrefetchHooks Function({
        bool appProfileRelationsRefs,
        bool websiteRulesRefs,
        bool intervalsRefs,
        bool usageLimitsRefs,
        bool geoAddressesRefs,
        bool wifiNetworksRefs,
      })
    >;
typedef $$ApplicationsTableCreateCompanionBuilder =
    ApplicationsCompanion Function({
      required String packageName,
      required String label,
      required String labelForSearch,
      Value<bool> isUninstalled,
      Value<int> rowid,
    });
typedef $$ApplicationsTableUpdateCompanionBuilder =
    ApplicationsCompanion Function({
      Value<String> packageName,
      Value<String> label,
      Value<String> labelForSearch,
      Value<bool> isUninstalled,
      Value<int> rowid,
    });

final class $$ApplicationsTableReferences
    extends BaseReferences<_$AppDatabase, $ApplicationsTable, Application> {
  $$ApplicationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FavoritesTable, List<Favorite>>
  _favoritesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.favorites,
    aliasName: $_aliasNameGenerator(
      db.applications.packageName,
      db.favorites.packageName,
    ),
  );

  $$FavoritesTableProcessedTableManager get favoritesRefs {
    final manager = $$FavoritesTableTableManager($_db, $_db.favorites).filter(
      (f) => f.packageName.packageName.sqlEquals(
        $_itemColumn<String>('package_name')!,
      ),
    );

    final cache = $_typedResult.readTableOrNull(_favoritesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ApplicationsTableFilterComposer
    extends Composer<_$AppDatabase, $ApplicationsTable> {
  $$ApplicationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labelForSearch => $composableBuilder(
    column: $table.labelForSearch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUninstalled => $composableBuilder(
    column: $table.isUninstalled,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> favoritesRefs(
    Expression<bool> Function($$FavoritesTableFilterComposer f) f,
  ) {
    final $$FavoritesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packageName,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.packageName,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableFilterComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ApplicationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ApplicationsTable> {
  $$ApplicationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labelForSearch => $composableBuilder(
    column: $table.labelForSearch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUninstalled => $composableBuilder(
    column: $table.isUninstalled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ApplicationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ApplicationsTable> {
  $$ApplicationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get labelForSearch => $composableBuilder(
    column: $table.labelForSearch,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isUninstalled => $composableBuilder(
    column: $table.isUninstalled,
    builder: (column) => column,
  );

  Expression<T> favoritesRefs<T extends Object>(
    Expression<T> Function($$FavoritesTableAnnotationComposer a) f,
  ) {
    final $$FavoritesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packageName,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.packageName,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableAnnotationComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ApplicationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ApplicationsTable,
          Application,
          $$ApplicationsTableFilterComposer,
          $$ApplicationsTableOrderingComposer,
          $$ApplicationsTableAnnotationComposer,
          $$ApplicationsTableCreateCompanionBuilder,
          $$ApplicationsTableUpdateCompanionBuilder,
          (Application, $$ApplicationsTableReferences),
          Application,
          PrefetchHooks Function({bool favoritesRefs})
        > {
  $$ApplicationsTableTableManager(_$AppDatabase db, $ApplicationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ApplicationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ApplicationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ApplicationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> packageName = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> labelForSearch = const Value.absent(),
                Value<bool> isUninstalled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ApplicationsCompanion(
                packageName: packageName,
                label: label,
                labelForSearch: labelForSearch,
                isUninstalled: isUninstalled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String packageName,
                required String label,
                required String labelForSearch,
                Value<bool> isUninstalled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ApplicationsCompanion.insert(
                packageName: packageName,
                label: label,
                labelForSearch: labelForSearch,
                isUninstalled: isUninstalled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ApplicationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({favoritesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (favoritesRefs) db.favorites],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (favoritesRefs)
                    await $_getPrefetchedData<
                      Application,
                      $ApplicationsTable,
                      Favorite
                    >(
                      currentTable: table,
                      referencedTable: $$ApplicationsTableReferences
                          ._favoritesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ApplicationsTableReferences(
                            db,
                            table,
                            p0,
                          ).favoritesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.packageName == item.packageName,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ApplicationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ApplicationsTable,
      Application,
      $$ApplicationsTableFilterComposer,
      $$ApplicationsTableOrderingComposer,
      $$ApplicationsTableAnnotationComposer,
      $$ApplicationsTableCreateCompanionBuilder,
      $$ApplicationsTableUpdateCompanionBuilder,
      (Application, $$ApplicationsTableReferences),
      Application,
      PrefetchHooks Function({bool favoritesRefs})
    >;
typedef $$AppProfileRelationsTableCreateCompanionBuilder =
    AppProfileRelationsCompanion Function({
      Value<int> id,
      required int profileId,
      required String packageName,
      Value<bool> isEnabled,
      Value<String?> overlayConfigJson,
      Value<String?> blockedSectionsJson,
    });
typedef $$AppProfileRelationsTableUpdateCompanionBuilder =
    AppProfileRelationsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> packageName,
      Value<bool> isEnabled,
      Value<String?> overlayConfigJson,
      Value<String?> blockedSectionsJson,
    });

final class $$AppProfileRelationsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AppProfileRelationsTable,
          AppProfileRelation
        > {
  $$AppProfileRelationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias(
        $_aliasNameGenerator(db.appProfileRelations.profileId, db.profiles.id),
      );

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AppProfileRelationsTableFilterComposer
    extends Composer<_$AppDatabase, $AppProfileRelationsTable> {
  $$AppProfileRelationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overlayConfigJson => $composableBuilder(
    column: $table.overlayConfigJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockedSectionsJson => $composableBuilder(
    column: $table.blockedSectionsJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppProfileRelationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppProfileRelationsTable> {
  $$AppProfileRelationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overlayConfigJson => $composableBuilder(
    column: $table.overlayConfigJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockedSectionsJson => $composableBuilder(
    column: $table.blockedSectionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppProfileRelationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppProfileRelationsTable> {
  $$AppProfileRelationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<String> get overlayConfigJson => $composableBuilder(
    column: $table.overlayConfigJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blockedSectionsJson => $composableBuilder(
    column: $table.blockedSectionsJson,
    builder: (column) => column,
  );

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppProfileRelationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppProfileRelationsTable,
          AppProfileRelation,
          $$AppProfileRelationsTableFilterComposer,
          $$AppProfileRelationsTableOrderingComposer,
          $$AppProfileRelationsTableAnnotationComposer,
          $$AppProfileRelationsTableCreateCompanionBuilder,
          $$AppProfileRelationsTableUpdateCompanionBuilder,
          (AppProfileRelation, $$AppProfileRelationsTableReferences),
          AppProfileRelation,
          PrefetchHooks Function({bool profileId})
        > {
  $$AppProfileRelationsTableTableManager(
    _$AppDatabase db,
    $AppProfileRelationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppProfileRelationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppProfileRelationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AppProfileRelationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> packageName = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<String?> overlayConfigJson = const Value.absent(),
                Value<String?> blockedSectionsJson = const Value.absent(),
              }) => AppProfileRelationsCompanion(
                id: id,
                profileId: profileId,
                packageName: packageName,
                isEnabled: isEnabled,
                overlayConfigJson: overlayConfigJson,
                blockedSectionsJson: blockedSectionsJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String packageName,
                Value<bool> isEnabled = const Value.absent(),
                Value<String?> overlayConfigJson = const Value.absent(),
                Value<String?> blockedSectionsJson = const Value.absent(),
              }) => AppProfileRelationsCompanion.insert(
                id: id,
                profileId: profileId,
                packageName: packageName,
                isEnabled: isEnabled,
                overlayConfigJson: overlayConfigJson,
                blockedSectionsJson: blockedSectionsJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AppProfileRelationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable:
                                    $$AppProfileRelationsTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$AppProfileRelationsTableReferences
                                        ._profileIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AppProfileRelationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppProfileRelationsTable,
      AppProfileRelation,
      $$AppProfileRelationsTableFilterComposer,
      $$AppProfileRelationsTableOrderingComposer,
      $$AppProfileRelationsTableAnnotationComposer,
      $$AppProfileRelationsTableCreateCompanionBuilder,
      $$AppProfileRelationsTableUpdateCompanionBuilder,
      (AppProfileRelation, $$AppProfileRelationsTableReferences),
      AppProfileRelation,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$WebsiteRulesTableCreateCompanionBuilder =
    WebsiteRulesCompanion Function({
      Value<int> id,
      required int profileId,
      required String name,
      Value<int> blockingType,
      Value<bool> isAnywhereInUrl,
      Value<bool> isEnabled,
    });
typedef $$WebsiteRulesTableUpdateCompanionBuilder =
    WebsiteRulesCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> name,
      Value<int> blockingType,
      Value<bool> isAnywhereInUrl,
      Value<bool> isEnabled,
    });

final class $$WebsiteRulesTableReferences
    extends BaseReferences<_$AppDatabase, $WebsiteRulesTable, WebsiteRule> {
  $$WebsiteRulesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias(
        $_aliasNameGenerator(db.websiteRules.profileId, db.profiles.id),
      );

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WebsiteRulesTableFilterComposer
    extends Composer<_$AppDatabase, $WebsiteRulesTable> {
  $$WebsiteRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blockingType => $composableBuilder(
    column: $table.blockingType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAnywhereInUrl => $composableBuilder(
    column: $table.isAnywhereInUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WebsiteRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $WebsiteRulesTable> {
  $$WebsiteRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blockingType => $composableBuilder(
    column: $table.blockingType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAnywhereInUrl => $composableBuilder(
    column: $table.isAnywhereInUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WebsiteRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WebsiteRulesTable> {
  $$WebsiteRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get blockingType => $composableBuilder(
    column: $table.blockingType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAnywhereInUrl => $composableBuilder(
    column: $table.isAnywhereInUrl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WebsiteRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WebsiteRulesTable,
          WebsiteRule,
          $$WebsiteRulesTableFilterComposer,
          $$WebsiteRulesTableOrderingComposer,
          $$WebsiteRulesTableAnnotationComposer,
          $$WebsiteRulesTableCreateCompanionBuilder,
          $$WebsiteRulesTableUpdateCompanionBuilder,
          (WebsiteRule, $$WebsiteRulesTableReferences),
          WebsiteRule,
          PrefetchHooks Function({bool profileId})
        > {
  $$WebsiteRulesTableTableManager(_$AppDatabase db, $WebsiteRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WebsiteRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WebsiteRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WebsiteRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> blockingType = const Value.absent(),
                Value<bool> isAnywhereInUrl = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
              }) => WebsiteRulesCompanion(
                id: id,
                profileId: profileId,
                name: name,
                blockingType: blockingType,
                isAnywhereInUrl: isAnywhereInUrl,
                isEnabled: isEnabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String name,
                Value<int> blockingType = const Value.absent(),
                Value<bool> isAnywhereInUrl = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
              }) => WebsiteRulesCompanion.insert(
                id: id,
                profileId: profileId,
                name: name,
                blockingType: blockingType,
                isAnywhereInUrl: isAnywhereInUrl,
                isEnabled: isEnabled,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WebsiteRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$WebsiteRulesTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$WebsiteRulesTableReferences
                                    ._profileIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WebsiteRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WebsiteRulesTable,
      WebsiteRule,
      $$WebsiteRulesTableFilterComposer,
      $$WebsiteRulesTableOrderingComposer,
      $$WebsiteRulesTableAnnotationComposer,
      $$WebsiteRulesTableCreateCompanionBuilder,
      $$WebsiteRulesTableUpdateCompanionBuilder,
      (WebsiteRule, $$WebsiteRulesTableReferences),
      WebsiteRule,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$IntervalsTableCreateCompanionBuilder =
    IntervalsCompanion Function({
      Value<int> id,
      required int profileId,
      required int fromMinutes,
      required int toMinutes,
      Value<int?> parentId,
      Value<bool> isAllDayAuto,
      Value<bool> isEnabled,
    });
typedef $$IntervalsTableUpdateCompanionBuilder =
    IntervalsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<int> fromMinutes,
      Value<int> toMinutes,
      Value<int?> parentId,
      Value<bool> isAllDayAuto,
      Value<bool> isEnabled,
    });

final class $$IntervalsTableReferences
    extends BaseReferences<_$AppDatabase, $IntervalsTable, Interval> {
  $$IntervalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias(
        $_aliasNameGenerator(db.intervals.profileId, db.profiles.id),
      );

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$IntervalsTableFilterComposer
    extends Composer<_$AppDatabase, $IntervalsTable> {
  $$IntervalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fromMinutes => $composableBuilder(
    column: $table.fromMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get toMinutes => $composableBuilder(
    column: $table.toMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAllDayAuto => $composableBuilder(
    column: $table.isAllDayAuto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IntervalsTableOrderingComposer
    extends Composer<_$AppDatabase, $IntervalsTable> {
  $$IntervalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fromMinutes => $composableBuilder(
    column: $table.fromMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get toMinutes => $composableBuilder(
    column: $table.toMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAllDayAuto => $composableBuilder(
    column: $table.isAllDayAuto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IntervalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IntervalsTable> {
  $$IntervalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get fromMinutes => $composableBuilder(
    column: $table.fromMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get toMinutes =>
      $composableBuilder(column: $table.toMinutes, builder: (column) => column);

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<bool> get isAllDayAuto => $composableBuilder(
    column: $table.isAllDayAuto,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IntervalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IntervalsTable,
          Interval,
          $$IntervalsTableFilterComposer,
          $$IntervalsTableOrderingComposer,
          $$IntervalsTableAnnotationComposer,
          $$IntervalsTableCreateCompanionBuilder,
          $$IntervalsTableUpdateCompanionBuilder,
          (Interval, $$IntervalsTableReferences),
          Interval,
          PrefetchHooks Function({bool profileId})
        > {
  $$IntervalsTableTableManager(_$AppDatabase db, $IntervalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IntervalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IntervalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IntervalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<int> fromMinutes = const Value.absent(),
                Value<int> toMinutes = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
                Value<bool> isAllDayAuto = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
              }) => IntervalsCompanion(
                id: id,
                profileId: profileId,
                fromMinutes: fromMinutes,
                toMinutes: toMinutes,
                parentId: parentId,
                isAllDayAuto: isAllDayAuto,
                isEnabled: isEnabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required int fromMinutes,
                required int toMinutes,
                Value<int?> parentId = const Value.absent(),
                Value<bool> isAllDayAuto = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
              }) => IntervalsCompanion.insert(
                id: id,
                profileId: profileId,
                fromMinutes: fromMinutes,
                toMinutes: toMinutes,
                parentId: parentId,
                isAllDayAuto: isAllDayAuto,
                isEnabled: isEnabled,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$IntervalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$IntervalsTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$IntervalsTableReferences
                                    ._profileIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$IntervalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IntervalsTable,
      Interval,
      $$IntervalsTableFilterComposer,
      $$IntervalsTableOrderingComposer,
      $$IntervalsTableAnnotationComposer,
      $$IntervalsTableCreateCompanionBuilder,
      $$IntervalsTableUpdateCompanionBuilder,
      (Interval, $$IntervalsTableReferences),
      Interval,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$UsageLimitsTableCreateCompanionBuilder =
    UsageLimitsCompanion Function({
      Value<int> id,
      required int profileId,
      Value<int> periodType,
      Value<int> limitType,
      Value<int> lastResetTime,
      Value<int> allowedCount,
      Value<int> usedCount,
      Value<int> originalAllowedCount,
    });
typedef $$UsageLimitsTableUpdateCompanionBuilder =
    UsageLimitsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<int> periodType,
      Value<int> limitType,
      Value<int> lastResetTime,
      Value<int> allowedCount,
      Value<int> usedCount,
      Value<int> originalAllowedCount,
    });

final class $$UsageLimitsTableReferences
    extends BaseReferences<_$AppDatabase, $UsageLimitsTable, UsageLimit> {
  $$UsageLimitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias(
        $_aliasNameGenerator(db.usageLimits.profileId, db.profiles.id),
      );

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UsageLimitsTableFilterComposer
    extends Composer<_$AppDatabase, $UsageLimitsTable> {
  $$UsageLimitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get periodType => $composableBuilder(
    column: $table.periodType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get limitType => $composableBuilder(
    column: $table.limitType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastResetTime => $composableBuilder(
    column: $table.lastResetTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get allowedCount => $composableBuilder(
    column: $table.allowedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usedCount => $composableBuilder(
    column: $table.usedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originalAllowedCount => $composableBuilder(
    column: $table.originalAllowedCount,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UsageLimitsTableOrderingComposer
    extends Composer<_$AppDatabase, $UsageLimitsTable> {
  $$UsageLimitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get periodType => $composableBuilder(
    column: $table.periodType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get limitType => $composableBuilder(
    column: $table.limitType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastResetTime => $composableBuilder(
    column: $table.lastResetTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get allowedCount => $composableBuilder(
    column: $table.allowedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usedCount => $composableBuilder(
    column: $table.usedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originalAllowedCount => $composableBuilder(
    column: $table.originalAllowedCount,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UsageLimitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsageLimitsTable> {
  $$UsageLimitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get periodType => $composableBuilder(
    column: $table.periodType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get limitType =>
      $composableBuilder(column: $table.limitType, builder: (column) => column);

  GeneratedColumn<int> get lastResetTime => $composableBuilder(
    column: $table.lastResetTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get allowedCount => $composableBuilder(
    column: $table.allowedCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get usedCount =>
      $composableBuilder(column: $table.usedCount, builder: (column) => column);

  GeneratedColumn<int> get originalAllowedCount => $composableBuilder(
    column: $table.originalAllowedCount,
    builder: (column) => column,
  );

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UsageLimitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsageLimitsTable,
          UsageLimit,
          $$UsageLimitsTableFilterComposer,
          $$UsageLimitsTableOrderingComposer,
          $$UsageLimitsTableAnnotationComposer,
          $$UsageLimitsTableCreateCompanionBuilder,
          $$UsageLimitsTableUpdateCompanionBuilder,
          (UsageLimit, $$UsageLimitsTableReferences),
          UsageLimit,
          PrefetchHooks Function({bool profileId})
        > {
  $$UsageLimitsTableTableManager(_$AppDatabase db, $UsageLimitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageLimitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsageLimitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsageLimitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<int> periodType = const Value.absent(),
                Value<int> limitType = const Value.absent(),
                Value<int> lastResetTime = const Value.absent(),
                Value<int> allowedCount = const Value.absent(),
                Value<int> usedCount = const Value.absent(),
                Value<int> originalAllowedCount = const Value.absent(),
              }) => UsageLimitsCompanion(
                id: id,
                profileId: profileId,
                periodType: periodType,
                limitType: limitType,
                lastResetTime: lastResetTime,
                allowedCount: allowedCount,
                usedCount: usedCount,
                originalAllowedCount: originalAllowedCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                Value<int> periodType = const Value.absent(),
                Value<int> limitType = const Value.absent(),
                Value<int> lastResetTime = const Value.absent(),
                Value<int> allowedCount = const Value.absent(),
                Value<int> usedCount = const Value.absent(),
                Value<int> originalAllowedCount = const Value.absent(),
              }) => UsageLimitsCompanion.insert(
                id: id,
                profileId: profileId,
                periodType: periodType,
                limitType: limitType,
                lastResetTime: lastResetTime,
                allowedCount: allowedCount,
                usedCount: usedCount,
                originalAllowedCount: originalAllowedCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$UsageLimitsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$UsageLimitsTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$UsageLimitsTableReferences
                                    ._profileIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$UsageLimitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsageLimitsTable,
      UsageLimit,
      $$UsageLimitsTableFilterComposer,
      $$UsageLimitsTableOrderingComposer,
      $$UsageLimitsTableAnnotationComposer,
      $$UsageLimitsTableCreateCompanionBuilder,
      $$UsageLimitsTableUpdateCompanionBuilder,
      (UsageLimit, $$UsageLimitsTableReferences),
      UsageLimit,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$GeoAddressesTableCreateCompanionBuilder =
    GeoAddressesCompanion Function({
      Value<int> id,
      required int profileId,
      required String geofenceId,
      Value<int> radiusMeters,
      required double latitude,
      required double longitude,
      Value<bool> isInverted,
      Value<String?> displayName,
    });
typedef $$GeoAddressesTableUpdateCompanionBuilder =
    GeoAddressesCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> geofenceId,
      Value<int> radiusMeters,
      Value<double> latitude,
      Value<double> longitude,
      Value<bool> isInverted,
      Value<String?> displayName,
    });

final class $$GeoAddressesTableReferences
    extends
        BaseReferences<_$AppDatabase, $GeoAddressesTable, GeoAddressesData> {
  $$GeoAddressesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias(
        $_aliasNameGenerator(db.geoAddresses.profileId, db.profiles.id),
      );

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GeoAddressesTableFilterComposer
    extends Composer<_$AppDatabase, $GeoAddressesTable> {
  $$GeoAddressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geofenceId => $composableBuilder(
    column: $table.geofenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInverted => $composableBuilder(
    column: $table.isInverted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GeoAddressesTableOrderingComposer
    extends Composer<_$AppDatabase, $GeoAddressesTable> {
  $$GeoAddressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geofenceId => $composableBuilder(
    column: $table.geofenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInverted => $composableBuilder(
    column: $table.isInverted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GeoAddressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GeoAddressesTable> {
  $$GeoAddressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get geofenceId => $composableBuilder(
    column: $table.geofenceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<bool> get isInverted => $composableBuilder(
    column: $table.isInverted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GeoAddressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GeoAddressesTable,
          GeoAddressesData,
          $$GeoAddressesTableFilterComposer,
          $$GeoAddressesTableOrderingComposer,
          $$GeoAddressesTableAnnotationComposer,
          $$GeoAddressesTableCreateCompanionBuilder,
          $$GeoAddressesTableUpdateCompanionBuilder,
          (GeoAddressesData, $$GeoAddressesTableReferences),
          GeoAddressesData,
          PrefetchHooks Function({bool profileId})
        > {
  $$GeoAddressesTableTableManager(_$AppDatabase db, $GeoAddressesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GeoAddressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GeoAddressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GeoAddressesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> geofenceId = const Value.absent(),
                Value<int> radiusMeters = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<bool> isInverted = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
              }) => GeoAddressesCompanion(
                id: id,
                profileId: profileId,
                geofenceId: geofenceId,
                radiusMeters: radiusMeters,
                latitude: latitude,
                longitude: longitude,
                isInverted: isInverted,
                displayName: displayName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String geofenceId,
                Value<int> radiusMeters = const Value.absent(),
                required double latitude,
                required double longitude,
                Value<bool> isInverted = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
              }) => GeoAddressesCompanion.insert(
                id: id,
                profileId: profileId,
                geofenceId: geofenceId,
                radiusMeters: radiusMeters,
                latitude: latitude,
                longitude: longitude,
                isInverted: isInverted,
                displayName: displayName,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GeoAddressesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$GeoAddressesTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$GeoAddressesTableReferences
                                    ._profileIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GeoAddressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GeoAddressesTable,
      GeoAddressesData,
      $$GeoAddressesTableFilterComposer,
      $$GeoAddressesTableOrderingComposer,
      $$GeoAddressesTableAnnotationComposer,
      $$GeoAddressesTableCreateCompanionBuilder,
      $$GeoAddressesTableUpdateCompanionBuilder,
      (GeoAddressesData, $$GeoAddressesTableReferences),
      GeoAddressesData,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$WifiNetworksTableCreateCompanionBuilder =
    WifiNetworksCompanion Function({
      Value<int> id,
      required int profileId,
      required String ssid,
    });
typedef $$WifiNetworksTableUpdateCompanionBuilder =
    WifiNetworksCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> ssid,
    });

final class $$WifiNetworksTableReferences
    extends BaseReferences<_$AppDatabase, $WifiNetworksTable, WifiNetwork> {
  $$WifiNetworksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias(
        $_aliasNameGenerator(db.wifiNetworks.profileId, db.profiles.id),
      );

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WifiNetworksTableFilterComposer
    extends Composer<_$AppDatabase, $WifiNetworksTable> {
  $$WifiNetworksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ssid => $composableBuilder(
    column: $table.ssid,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WifiNetworksTableOrderingComposer
    extends Composer<_$AppDatabase, $WifiNetworksTable> {
  $$WifiNetworksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ssid => $composableBuilder(
    column: $table.ssid,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WifiNetworksTableAnnotationComposer
    extends Composer<_$AppDatabase, $WifiNetworksTable> {
  $$WifiNetworksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ssid =>
      $composableBuilder(column: $table.ssid, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WifiNetworksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WifiNetworksTable,
          WifiNetwork,
          $$WifiNetworksTableFilterComposer,
          $$WifiNetworksTableOrderingComposer,
          $$WifiNetworksTableAnnotationComposer,
          $$WifiNetworksTableCreateCompanionBuilder,
          $$WifiNetworksTableUpdateCompanionBuilder,
          (WifiNetwork, $$WifiNetworksTableReferences),
          WifiNetwork,
          PrefetchHooks Function({bool profileId})
        > {
  $$WifiNetworksTableTableManager(_$AppDatabase db, $WifiNetworksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WifiNetworksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WifiNetworksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WifiNetworksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> ssid = const Value.absent(),
              }) => WifiNetworksCompanion(
                id: id,
                profileId: profileId,
                ssid: ssid,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String ssid,
              }) => WifiNetworksCompanion.insert(
                id: id,
                profileId: profileId,
                ssid: ssid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WifiNetworksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$WifiNetworksTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$WifiNetworksTableReferences
                                    ._profileIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WifiNetworksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WifiNetworksTable,
      WifiNetwork,
      $$WifiNetworksTableFilterComposer,
      $$WifiNetworksTableOrderingComposer,
      $$WifiNetworksTableAnnotationComposer,
      $$WifiNetworksTableCreateCompanionBuilder,
      $$WifiNetworksTableUpdateCompanionBuilder,
      (WifiNetwork, $$WifiNetworksTableReferences),
      WifiNetwork,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$BlockSessionsTableCreateCompanionBuilder =
    BlockSessionsCompanion Function({
      Value<int> id,
      required String name,
      required int timestamp,
    });
typedef $$BlockSessionsTableUpdateCompanionBuilder =
    BlockSessionsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> timestamp,
    });

class $$BlockSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $BlockSessionsTable> {
  $$BlockSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlockSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $BlockSessionsTable> {
  $$BlockSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlockSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlockSessionsTable> {
  $$BlockSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$BlockSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlockSessionsTable,
          BlockSession,
          $$BlockSessionsTableFilterComposer,
          $$BlockSessionsTableOrderingComposer,
          $$BlockSessionsTableAnnotationComposer,
          $$BlockSessionsTableCreateCompanionBuilder,
          $$BlockSessionsTableUpdateCompanionBuilder,
          (
            BlockSession,
            BaseReferences<_$AppDatabase, $BlockSessionsTable, BlockSession>,
          ),
          BlockSession,
          PrefetchHooks Function()
        > {
  $$BlockSessionsTableTableManager(_$AppDatabase db, $BlockSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlockSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlockSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlockSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
              }) => BlockSessionsCompanion(
                id: id,
                name: name,
                timestamp: timestamp,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int timestamp,
              }) => BlockSessionsCompanion.insert(
                id: id,
                name: name,
                timestamp: timestamp,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlockSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlockSessionsTable,
      BlockSession,
      $$BlockSessionsTableFilterComposer,
      $$BlockSessionsTableOrderingComposer,
      $$BlockSessionsTableAnnotationComposer,
      $$BlockSessionsTableCreateCompanionBuilder,
      $$BlockSessionsTableUpdateCompanionBuilder,
      (
        BlockSession,
        BaseReferences<_$AppDatabase, $BlockSessionsTable, BlockSession>,
      ),
      BlockSession,
      PrefetchHooks Function()
    >;
typedef $$BrowserConfigsTableCreateCompanionBuilder =
    BrowserConfigsCompanion Function({
      Value<int> id,
      required String packageName,
      required String viewId,
      Value<int> viewType,
      Value<bool> clearUrl,
      Value<String> detectionMethod,
      Value<String> extractionMethod,
      Value<String?> clickToOpenViewId,
    });
typedef $$BrowserConfigsTableUpdateCompanionBuilder =
    BrowserConfigsCompanion Function({
      Value<int> id,
      Value<String> packageName,
      Value<String> viewId,
      Value<int> viewType,
      Value<bool> clearUrl,
      Value<String> detectionMethod,
      Value<String> extractionMethod,
      Value<String?> clickToOpenViewId,
    });

class $$BrowserConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $BrowserConfigsTable> {
  $$BrowserConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viewId => $composableBuilder(
    column: $table.viewId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get viewType => $composableBuilder(
    column: $table.viewType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get clearUrl => $composableBuilder(
    column: $table.clearUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detectionMethod => $composableBuilder(
    column: $table.detectionMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractionMethod => $composableBuilder(
    column: $table.extractionMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clickToOpenViewId => $composableBuilder(
    column: $table.clickToOpenViewId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BrowserConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $BrowserConfigsTable> {
  $$BrowserConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viewId => $composableBuilder(
    column: $table.viewId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get viewType => $composableBuilder(
    column: $table.viewType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get clearUrl => $composableBuilder(
    column: $table.clearUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detectionMethod => $composableBuilder(
    column: $table.detectionMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractionMethod => $composableBuilder(
    column: $table.extractionMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clickToOpenViewId => $composableBuilder(
    column: $table.clickToOpenViewId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BrowserConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BrowserConfigsTable> {
  $$BrowserConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viewId =>
      $composableBuilder(column: $table.viewId, builder: (column) => column);

  GeneratedColumn<int> get viewType =>
      $composableBuilder(column: $table.viewType, builder: (column) => column);

  GeneratedColumn<bool> get clearUrl =>
      $composableBuilder(column: $table.clearUrl, builder: (column) => column);

  GeneratedColumn<String> get detectionMethod => $composableBuilder(
    column: $table.detectionMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extractionMethod => $composableBuilder(
    column: $table.extractionMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clickToOpenViewId => $composableBuilder(
    column: $table.clickToOpenViewId,
    builder: (column) => column,
  );
}

class $$BrowserConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BrowserConfigsTable,
          BrowserConfig,
          $$BrowserConfigsTableFilterComposer,
          $$BrowserConfigsTableOrderingComposer,
          $$BrowserConfigsTableAnnotationComposer,
          $$BrowserConfigsTableCreateCompanionBuilder,
          $$BrowserConfigsTableUpdateCompanionBuilder,
          (
            BrowserConfig,
            BaseReferences<_$AppDatabase, $BrowserConfigsTable, BrowserConfig>,
          ),
          BrowserConfig,
          PrefetchHooks Function()
        > {
  $$BrowserConfigsTableTableManager(
    _$AppDatabase db,
    $BrowserConfigsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BrowserConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BrowserConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BrowserConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> packageName = const Value.absent(),
                Value<String> viewId = const Value.absent(),
                Value<int> viewType = const Value.absent(),
                Value<bool> clearUrl = const Value.absent(),
                Value<String> detectionMethod = const Value.absent(),
                Value<String> extractionMethod = const Value.absent(),
                Value<String?> clickToOpenViewId = const Value.absent(),
              }) => BrowserConfigsCompanion(
                id: id,
                packageName: packageName,
                viewId: viewId,
                viewType: viewType,
                clearUrl: clearUrl,
                detectionMethod: detectionMethod,
                extractionMethod: extractionMethod,
                clickToOpenViewId: clickToOpenViewId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String packageName,
                required String viewId,
                Value<int> viewType = const Value.absent(),
                Value<bool> clearUrl = const Value.absent(),
                Value<String> detectionMethod = const Value.absent(),
                Value<String> extractionMethod = const Value.absent(),
                Value<String?> clickToOpenViewId = const Value.absent(),
              }) => BrowserConfigsCompanion.insert(
                id: id,
                packageName: packageName,
                viewId: viewId,
                viewType: viewType,
                clearUrl: clearUrl,
                detectionMethod: detectionMethod,
                extractionMethod: extractionMethod,
                clickToOpenViewId: clickToOpenViewId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BrowserConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BrowserConfigsTable,
      BrowserConfig,
      $$BrowserConfigsTableFilterComposer,
      $$BrowserConfigsTableOrderingComposer,
      $$BrowserConfigsTableAnnotationComposer,
      $$BrowserConfigsTableCreateCompanionBuilder,
      $$BrowserConfigsTableUpdateCompanionBuilder,
      (
        BrowserConfig,
        BaseReferences<_$AppDatabase, $BrowserConfigsTable, BrowserConfig>,
      ),
      BrowserConfig,
      PrefetchHooks Function()
    >;
typedef $$AdultContentSitesTableCreateCompanionBuilder =
    AdultContentSitesCompanion Function({
      required String domain,
      Value<int> rowid,
    });
typedef $$AdultContentSitesTableUpdateCompanionBuilder =
    AdultContentSitesCompanion Function({
      Value<String> domain,
      Value<int> rowid,
    });

class $$AdultContentSitesTableFilterComposer
    extends Composer<_$AppDatabase, $AdultContentSitesTable> {
  $$AdultContentSitesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get domain => $composableBuilder(
    column: $table.domain,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AdultContentSitesTableOrderingComposer
    extends Composer<_$AppDatabase, $AdultContentSitesTable> {
  $$AdultContentSitesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get domain => $composableBuilder(
    column: $table.domain,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AdultContentSitesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AdultContentSitesTable> {
  $$AdultContentSitesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get domain =>
      $composableBuilder(column: $table.domain, builder: (column) => column);
}

class $$AdultContentSitesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AdultContentSitesTable,
          AdultContentSite,
          $$AdultContentSitesTableFilterComposer,
          $$AdultContentSitesTableOrderingComposer,
          $$AdultContentSitesTableAnnotationComposer,
          $$AdultContentSitesTableCreateCompanionBuilder,
          $$AdultContentSitesTableUpdateCompanionBuilder,
          (
            AdultContentSite,
            BaseReferences<
              _$AppDatabase,
              $AdultContentSitesTable,
              AdultContentSite
            >,
          ),
          AdultContentSite,
          PrefetchHooks Function()
        > {
  $$AdultContentSitesTableTableManager(
    _$AppDatabase db,
    $AdultContentSitesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AdultContentSitesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AdultContentSitesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AdultContentSitesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> domain = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AdultContentSitesCompanion(domain: domain, rowid: rowid),
          createCompanionCallback:
              ({
                required String domain,
                Value<int> rowid = const Value.absent(),
              }) => AdultContentSitesCompanion.insert(
                domain: domain,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AdultContentSitesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AdultContentSitesTable,
      AdultContentSite,
      $$AdultContentSitesTableFilterComposer,
      $$AdultContentSitesTableOrderingComposer,
      $$AdultContentSitesTableAnnotationComposer,
      $$AdultContentSitesTableCreateCompanionBuilder,
      $$AdultContentSitesTableUpdateCompanionBuilder,
      (
        AdultContentSite,
        BaseReferences<
          _$AppDatabase,
          $AdultContentSitesTable,
          AdultContentSite
        >,
      ),
      AdultContentSite,
      PrefetchHooks Function()
    >;
typedef $$PomodoroSessionsTableCreateCompanionBuilder =
    PomodoroSessionsCompanion Function({
      Value<int> id,
      required int profileId,
      required int workMs,
      required int breakMs,
      required int cycles,
      required int startTime,
      required int endTime,
      Value<bool> isStoppedManually,
    });
typedef $$PomodoroSessionsTableUpdateCompanionBuilder =
    PomodoroSessionsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<int> workMs,
      Value<int> breakMs,
      Value<int> cycles,
      Value<int> startTime,
      Value<int> endTime,
      Value<bool> isStoppedManually,
    });

class $$PomodoroSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PomodoroSessionsTable> {
  $$PomodoroSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get workMs => $composableBuilder(
    column: $table.workMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get breakMs => $composableBuilder(
    column: $table.breakMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cycles => $composableBuilder(
    column: $table.cycles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isStoppedManually => $composableBuilder(
    column: $table.isStoppedManually,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PomodoroSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PomodoroSessionsTable> {
  $$PomodoroSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get workMs => $composableBuilder(
    column: $table.workMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get breakMs => $composableBuilder(
    column: $table.breakMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cycles => $composableBuilder(
    column: $table.cycles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isStoppedManually => $composableBuilder(
    column: $table.isStoppedManually,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PomodoroSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PomodoroSessionsTable> {
  $$PomodoroSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get workMs =>
      $composableBuilder(column: $table.workMs, builder: (column) => column);

  GeneratedColumn<int> get breakMs =>
      $composableBuilder(column: $table.breakMs, builder: (column) => column);

  GeneratedColumn<int> get cycles =>
      $composableBuilder(column: $table.cycles, builder: (column) => column);

  GeneratedColumn<int> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<int> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<bool> get isStoppedManually => $composableBuilder(
    column: $table.isStoppedManually,
    builder: (column) => column,
  );
}

class $$PomodoroSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PomodoroSessionsTable,
          PomodoroSession,
          $$PomodoroSessionsTableFilterComposer,
          $$PomodoroSessionsTableOrderingComposer,
          $$PomodoroSessionsTableAnnotationComposer,
          $$PomodoroSessionsTableCreateCompanionBuilder,
          $$PomodoroSessionsTableUpdateCompanionBuilder,
          (
            PomodoroSession,
            BaseReferences<
              _$AppDatabase,
              $PomodoroSessionsTable,
              PomodoroSession
            >,
          ),
          PomodoroSession,
          PrefetchHooks Function()
        > {
  $$PomodoroSessionsTableTableManager(
    _$AppDatabase db,
    $PomodoroSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PomodoroSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PomodoroSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PomodoroSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<int> workMs = const Value.absent(),
                Value<int> breakMs = const Value.absent(),
                Value<int> cycles = const Value.absent(),
                Value<int> startTime = const Value.absent(),
                Value<int> endTime = const Value.absent(),
                Value<bool> isStoppedManually = const Value.absent(),
              }) => PomodoroSessionsCompanion(
                id: id,
                profileId: profileId,
                workMs: workMs,
                breakMs: breakMs,
                cycles: cycles,
                startTime: startTime,
                endTime: endTime,
                isStoppedManually: isStoppedManually,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required int workMs,
                required int breakMs,
                required int cycles,
                required int startTime,
                required int endTime,
                Value<bool> isStoppedManually = const Value.absent(),
              }) => PomodoroSessionsCompanion.insert(
                id: id,
                profileId: profileId,
                workMs: workMs,
                breakMs: breakMs,
                cycles: cycles,
                startTime: startTime,
                endTime: endTime,
                isStoppedManually: isStoppedManually,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PomodoroSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PomodoroSessionsTable,
      PomodoroSession,
      $$PomodoroSessionsTableFilterComposer,
      $$PomodoroSessionsTableOrderingComposer,
      $$PomodoroSessionsTableAnnotationComposer,
      $$PomodoroSessionsTableCreateCompanionBuilder,
      $$PomodoroSessionsTableUpdateCompanionBuilder,
      (
        PomodoroSession,
        BaseReferences<_$AppDatabase, $PomodoroSessionsTable, PomodoroSession>,
      ),
      PomodoroSession,
      PrefetchHooks Function()
    >;
typedef $$BlockingConfigsTableCreateCompanionBuilder =
    BlockingConfigsCompanion Function({
      required String id,
      Value<int> configType,
      Value<String> blockingMessage,
      Value<int> timeoutSeconds,
      Value<String> customTitle,
      Value<String> customSubtitle,
      Value<String> customExitButtonText,
      Value<String> customColorHex,
      Value<int> rowid,
    });
typedef $$BlockingConfigsTableUpdateCompanionBuilder =
    BlockingConfigsCompanion Function({
      Value<String> id,
      Value<int> configType,
      Value<String> blockingMessage,
      Value<int> timeoutSeconds,
      Value<String> customTitle,
      Value<String> customSubtitle,
      Value<String> customExitButtonText,
      Value<String> customColorHex,
      Value<int> rowid,
    });

class $$BlockingConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $BlockingConfigsTable> {
  $$BlockingConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get configType => $composableBuilder(
    column: $table.configType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockingMessage => $composableBuilder(
    column: $table.blockingMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeoutSeconds => $composableBuilder(
    column: $table.timeoutSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customTitle => $composableBuilder(
    column: $table.customTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customSubtitle => $composableBuilder(
    column: $table.customSubtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customExitButtonText => $composableBuilder(
    column: $table.customExitButtonText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customColorHex => $composableBuilder(
    column: $table.customColorHex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlockingConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $BlockingConfigsTable> {
  $$BlockingConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get configType => $composableBuilder(
    column: $table.configType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockingMessage => $composableBuilder(
    column: $table.blockingMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeoutSeconds => $composableBuilder(
    column: $table.timeoutSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customTitle => $composableBuilder(
    column: $table.customTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customSubtitle => $composableBuilder(
    column: $table.customSubtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customExitButtonText => $composableBuilder(
    column: $table.customExitButtonText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customColorHex => $composableBuilder(
    column: $table.customColorHex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlockingConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlockingConfigsTable> {
  $$BlockingConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get configType => $composableBuilder(
    column: $table.configType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blockingMessage => $composableBuilder(
    column: $table.blockingMessage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timeoutSeconds => $composableBuilder(
    column: $table.timeoutSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customTitle => $composableBuilder(
    column: $table.customTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customSubtitle => $composableBuilder(
    column: $table.customSubtitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customExitButtonText => $composableBuilder(
    column: $table.customExitButtonText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customColorHex => $composableBuilder(
    column: $table.customColorHex,
    builder: (column) => column,
  );
}

class $$BlockingConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlockingConfigsTable,
          BlockingConfig,
          $$BlockingConfigsTableFilterComposer,
          $$BlockingConfigsTableOrderingComposer,
          $$BlockingConfigsTableAnnotationComposer,
          $$BlockingConfigsTableCreateCompanionBuilder,
          $$BlockingConfigsTableUpdateCompanionBuilder,
          (
            BlockingConfig,
            BaseReferences<
              _$AppDatabase,
              $BlockingConfigsTable,
              BlockingConfig
            >,
          ),
          BlockingConfig,
          PrefetchHooks Function()
        > {
  $$BlockingConfigsTableTableManager(
    _$AppDatabase db,
    $BlockingConfigsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlockingConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlockingConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlockingConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> configType = const Value.absent(),
                Value<String> blockingMessage = const Value.absent(),
                Value<int> timeoutSeconds = const Value.absent(),
                Value<String> customTitle = const Value.absent(),
                Value<String> customSubtitle = const Value.absent(),
                Value<String> customExitButtonText = const Value.absent(),
                Value<String> customColorHex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlockingConfigsCompanion(
                id: id,
                configType: configType,
                blockingMessage: blockingMessage,
                timeoutSeconds: timeoutSeconds,
                customTitle: customTitle,
                customSubtitle: customSubtitle,
                customExitButtonText: customExitButtonText,
                customColorHex: customColorHex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> configType = const Value.absent(),
                Value<String> blockingMessage = const Value.absent(),
                Value<int> timeoutSeconds = const Value.absent(),
                Value<String> customTitle = const Value.absent(),
                Value<String> customSubtitle = const Value.absent(),
                Value<String> customExitButtonText = const Value.absent(),
                Value<String> customColorHex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlockingConfigsCompanion.insert(
                id: id,
                configType: configType,
                blockingMessage: blockingMessage,
                timeoutSeconds: timeoutSeconds,
                customTitle: customTitle,
                customSubtitle: customSubtitle,
                customExitButtonText: customExitButtonText,
                customColorHex: customColorHex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlockingConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlockingConfigsTable,
      BlockingConfig,
      $$BlockingConfigsTableFilterComposer,
      $$BlockingConfigsTableOrderingComposer,
      $$BlockingConfigsTableAnnotationComposer,
      $$BlockingConfigsTableCreateCompanionBuilder,
      $$BlockingConfigsTableUpdateCompanionBuilder,
      (
        BlockingConfig,
        BaseReferences<_$AppDatabase, $BlockingConfigsTable, BlockingConfig>,
      ),
      BlockingConfig,
      PrefetchHooks Function()
    >;
typedef $$MoodCheckInsTableCreateCompanionBuilder =
    MoodCheckInsCompanion Function({
      Value<int> id,
      required int mood,
      required String day,
      required int createdAt,
      Value<String?> note,
      Value<String?> tagsJson,
    });
typedef $$MoodCheckInsTableUpdateCompanionBuilder =
    MoodCheckInsCompanion Function({
      Value<int> id,
      Value<int> mood,
      Value<String> day,
      Value<int> createdAt,
      Value<String?> note,
      Value<String?> tagsJson,
    });

class $$MoodCheckInsTableFilterComposer
    extends Composer<_$AppDatabase, $MoodCheckInsTable> {
  $$MoodCheckInsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MoodCheckInsTableOrderingComposer
    extends Composer<_$AppDatabase, $MoodCheckInsTable> {
  $$MoodCheckInsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MoodCheckInsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MoodCheckInsTable> {
  $$MoodCheckInsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);
}

class $$MoodCheckInsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MoodCheckInsTable,
          MoodCheckIn,
          $$MoodCheckInsTableFilterComposer,
          $$MoodCheckInsTableOrderingComposer,
          $$MoodCheckInsTableAnnotationComposer,
          $$MoodCheckInsTableCreateCompanionBuilder,
          $$MoodCheckInsTableUpdateCompanionBuilder,
          (
            MoodCheckIn,
            BaseReferences<_$AppDatabase, $MoodCheckInsTable, MoodCheckIn>,
          ),
          MoodCheckIn,
          PrefetchHooks Function()
        > {
  $$MoodCheckInsTableTableManager(_$AppDatabase db, $MoodCheckInsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoodCheckInsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoodCheckInsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoodCheckInsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mood = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> tagsJson = const Value.absent(),
              }) => MoodCheckInsCompanion(
                id: id,
                mood: mood,
                day: day,
                createdAt: createdAt,
                note: note,
                tagsJson: tagsJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mood,
                required String day,
                required int createdAt,
                Value<String?> note = const Value.absent(),
                Value<String?> tagsJson = const Value.absent(),
              }) => MoodCheckInsCompanion.insert(
                id: id,
                mood: mood,
                day: day,
                createdAt: createdAt,
                note: note,
                tagsJson: tagsJson,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MoodCheckInsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MoodCheckInsTable,
      MoodCheckIn,
      $$MoodCheckInsTableFilterComposer,
      $$MoodCheckInsTableOrderingComposer,
      $$MoodCheckInsTableAnnotationComposer,
      $$MoodCheckInsTableCreateCompanionBuilder,
      $$MoodCheckInsTableUpdateCompanionBuilder,
      (
        MoodCheckIn,
        BaseReferences<_$AppDatabase, $MoodCheckInsTable, MoodCheckIn>,
      ),
      MoodCheckIn,
      PrefetchHooks Function()
    >;
typedef $$EmergencyUnblocksTableCreateCompanionBuilder =
    EmergencyUnblocksCompanion Function({
      Value<int> id,
      required int timestamp,
    });
typedef $$EmergencyUnblocksTableUpdateCompanionBuilder =
    EmergencyUnblocksCompanion Function({Value<int> id, Value<int> timestamp});

class $$EmergencyUnblocksTableFilterComposer
    extends Composer<_$AppDatabase, $EmergencyUnblocksTable> {
  $$EmergencyUnblocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmergencyUnblocksTableOrderingComposer
    extends Composer<_$AppDatabase, $EmergencyUnblocksTable> {
  $$EmergencyUnblocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmergencyUnblocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmergencyUnblocksTable> {
  $$EmergencyUnblocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$EmergencyUnblocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmergencyUnblocksTable,
          EmergencyUnblock,
          $$EmergencyUnblocksTableFilterComposer,
          $$EmergencyUnblocksTableOrderingComposer,
          $$EmergencyUnblocksTableAnnotationComposer,
          $$EmergencyUnblocksTableCreateCompanionBuilder,
          $$EmergencyUnblocksTableUpdateCompanionBuilder,
          (
            EmergencyUnblock,
            BaseReferences<
              _$AppDatabase,
              $EmergencyUnblocksTable,
              EmergencyUnblock
            >,
          ),
          EmergencyUnblock,
          PrefetchHooks Function()
        > {
  $$EmergencyUnblocksTableTableManager(
    _$AppDatabase db,
    $EmergencyUnblocksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmergencyUnblocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmergencyUnblocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmergencyUnblocksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
              }) => EmergencyUnblocksCompanion(id: id, timestamp: timestamp),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int timestamp,
              }) => EmergencyUnblocksCompanion.insert(
                id: id,
                timestamp: timestamp,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmergencyUnblocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmergencyUnblocksTable,
      EmergencyUnblock,
      $$EmergencyUnblocksTableFilterComposer,
      $$EmergencyUnblocksTableOrderingComposer,
      $$EmergencyUnblocksTableAnnotationComposer,
      $$EmergencyUnblocksTableCreateCompanionBuilder,
      $$EmergencyUnblocksTableUpdateCompanionBuilder,
      (
        EmergencyUnblock,
        BaseReferences<
          _$AppDatabase,
          $EmergencyUnblocksTable,
          EmergencyUnblock
        >,
      ),
      EmergencyUnblock,
      PrefetchHooks Function()
    >;
typedef $$UsedBackdoorCodesTableCreateCompanionBuilder =
    UsedBackdoorCodesCompanion Function({
      Value<int> id,
      required String code,
      required int usedAt,
    });
typedef $$UsedBackdoorCodesTableUpdateCompanionBuilder =
    UsedBackdoorCodesCompanion Function({
      Value<int> id,
      Value<String> code,
      Value<int> usedAt,
    });

class $$UsedBackdoorCodesTableFilterComposer
    extends Composer<_$AppDatabase, $UsedBackdoorCodesTable> {
  $$UsedBackdoorCodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usedAt => $composableBuilder(
    column: $table.usedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsedBackdoorCodesTableOrderingComposer
    extends Composer<_$AppDatabase, $UsedBackdoorCodesTable> {
  $$UsedBackdoorCodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usedAt => $composableBuilder(
    column: $table.usedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsedBackdoorCodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsedBackdoorCodesTable> {
  $$UsedBackdoorCodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<int> get usedAt =>
      $composableBuilder(column: $table.usedAt, builder: (column) => column);
}

class $$UsedBackdoorCodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsedBackdoorCodesTable,
          UsedBackdoorCode,
          $$UsedBackdoorCodesTableFilterComposer,
          $$UsedBackdoorCodesTableOrderingComposer,
          $$UsedBackdoorCodesTableAnnotationComposer,
          $$UsedBackdoorCodesTableCreateCompanionBuilder,
          $$UsedBackdoorCodesTableUpdateCompanionBuilder,
          (
            UsedBackdoorCode,
            BaseReferences<
              _$AppDatabase,
              $UsedBackdoorCodesTable,
              UsedBackdoorCode
            >,
          ),
          UsedBackdoorCode,
          PrefetchHooks Function()
        > {
  $$UsedBackdoorCodesTableTableManager(
    _$AppDatabase db,
    $UsedBackdoorCodesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsedBackdoorCodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsedBackdoorCodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsedBackdoorCodesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<int> usedAt = const Value.absent(),
              }) => UsedBackdoorCodesCompanion(
                id: id,
                code: code,
                usedAt: usedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String code,
                required int usedAt,
              }) => UsedBackdoorCodesCompanion.insert(
                id: id,
                code: code,
                usedAt: usedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsedBackdoorCodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsedBackdoorCodesTable,
      UsedBackdoorCode,
      $$UsedBackdoorCodesTableFilterComposer,
      $$UsedBackdoorCodesTableOrderingComposer,
      $$UsedBackdoorCodesTableAnnotationComposer,
      $$UsedBackdoorCodesTableCreateCompanionBuilder,
      $$UsedBackdoorCodesTableUpdateCompanionBuilder,
      (
        UsedBackdoorCode,
        BaseReferences<
          _$AppDatabase,
          $UsedBackdoorCodesTable,
          UsedBackdoorCode
        >,
      ),
      UsedBackdoorCode,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$RestrictedAccessEventsTableCreateCompanionBuilder =
    RestrictedAccessEventsCompanion Function({
      Value<int> id,
      required int occurredAt,
      required String dayStartDate,
      required String packageName,
      required int eventType,
      required int restrictionType,
    });
typedef $$RestrictedAccessEventsTableUpdateCompanionBuilder =
    RestrictedAccessEventsCompanion Function({
      Value<int> id,
      Value<int> occurredAt,
      Value<String> dayStartDate,
      Value<String> packageName,
      Value<int> eventType,
      Value<int> restrictionType,
    });

class $$RestrictedAccessEventsTableFilterComposer
    extends Composer<_$AppDatabase, $RestrictedAccessEventsTable> {
  $$RestrictedAccessEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayStartDate => $composableBuilder(
    column: $table.dayStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restrictionType => $composableBuilder(
    column: $table.restrictionType,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RestrictedAccessEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $RestrictedAccessEventsTable> {
  $$RestrictedAccessEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayStartDate => $composableBuilder(
    column: $table.dayStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restrictionType => $composableBuilder(
    column: $table.restrictionType,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RestrictedAccessEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RestrictedAccessEventsTable> {
  $$RestrictedAccessEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dayStartDate => $composableBuilder(
    column: $table.dayStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<int> get restrictionType => $composableBuilder(
    column: $table.restrictionType,
    builder: (column) => column,
  );
}

class $$RestrictedAccessEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RestrictedAccessEventsTable,
          RestrictedAccessEvent,
          $$RestrictedAccessEventsTableFilterComposer,
          $$RestrictedAccessEventsTableOrderingComposer,
          $$RestrictedAccessEventsTableAnnotationComposer,
          $$RestrictedAccessEventsTableCreateCompanionBuilder,
          $$RestrictedAccessEventsTableUpdateCompanionBuilder,
          (
            RestrictedAccessEvent,
            BaseReferences<
              _$AppDatabase,
              $RestrictedAccessEventsTable,
              RestrictedAccessEvent
            >,
          ),
          RestrictedAccessEvent,
          PrefetchHooks Function()
        > {
  $$RestrictedAccessEventsTableTableManager(
    _$AppDatabase db,
    $RestrictedAccessEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RestrictedAccessEventsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RestrictedAccessEventsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RestrictedAccessEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> occurredAt = const Value.absent(),
                Value<String> dayStartDate = const Value.absent(),
                Value<String> packageName = const Value.absent(),
                Value<int> eventType = const Value.absent(),
                Value<int> restrictionType = const Value.absent(),
              }) => RestrictedAccessEventsCompanion(
                id: id,
                occurredAt: occurredAt,
                dayStartDate: dayStartDate,
                packageName: packageName,
                eventType: eventType,
                restrictionType: restrictionType,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int occurredAt,
                required String dayStartDate,
                required String packageName,
                required int eventType,
                required int restrictionType,
              }) => RestrictedAccessEventsCompanion.insert(
                id: id,
                occurredAt: occurredAt,
                dayStartDate: dayStartDate,
                packageName: packageName,
                eventType: eventType,
                restrictionType: restrictionType,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RestrictedAccessEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RestrictedAccessEventsTable,
      RestrictedAccessEvent,
      $$RestrictedAccessEventsTableFilterComposer,
      $$RestrictedAccessEventsTableOrderingComposer,
      $$RestrictedAccessEventsTableAnnotationComposer,
      $$RestrictedAccessEventsTableCreateCompanionBuilder,
      $$RestrictedAccessEventsTableUpdateCompanionBuilder,
      (
        RestrictedAccessEvent,
        BaseReferences<
          _$AppDatabase,
          $RestrictedAccessEventsTable,
          RestrictedAccessEvent
        >,
      ),
      RestrictedAccessEvent,
      PrefetchHooks Function()
    >;
typedef $$IntentionUsageEventsTableCreateCompanionBuilder =
    IntentionUsageEventsCompanion Function({
      Value<int> id,
      required int occurredAt,
      required String dayStartDate,
      required String packageName,
      required String intentionName,
    });
typedef $$IntentionUsageEventsTableUpdateCompanionBuilder =
    IntentionUsageEventsCompanion Function({
      Value<int> id,
      Value<int> occurredAt,
      Value<String> dayStartDate,
      Value<String> packageName,
      Value<String> intentionName,
    });

class $$IntentionUsageEventsTableFilterComposer
    extends Composer<_$AppDatabase, $IntentionUsageEventsTable> {
  $$IntentionUsageEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayStartDate => $composableBuilder(
    column: $table.dayStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intentionName => $composableBuilder(
    column: $table.intentionName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IntentionUsageEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $IntentionUsageEventsTable> {
  $$IntentionUsageEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayStartDate => $composableBuilder(
    column: $table.dayStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intentionName => $composableBuilder(
    column: $table.intentionName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IntentionUsageEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IntentionUsageEventsTable> {
  $$IntentionUsageEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dayStartDate => $composableBuilder(
    column: $table.dayStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get intentionName => $composableBuilder(
    column: $table.intentionName,
    builder: (column) => column,
  );
}

class $$IntentionUsageEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IntentionUsageEventsTable,
          IntentionUsageEvent,
          $$IntentionUsageEventsTableFilterComposer,
          $$IntentionUsageEventsTableOrderingComposer,
          $$IntentionUsageEventsTableAnnotationComposer,
          $$IntentionUsageEventsTableCreateCompanionBuilder,
          $$IntentionUsageEventsTableUpdateCompanionBuilder,
          (
            IntentionUsageEvent,
            BaseReferences<
              _$AppDatabase,
              $IntentionUsageEventsTable,
              IntentionUsageEvent
            >,
          ),
          IntentionUsageEvent,
          PrefetchHooks Function()
        > {
  $$IntentionUsageEventsTableTableManager(
    _$AppDatabase db,
    $IntentionUsageEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IntentionUsageEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IntentionUsageEventsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$IntentionUsageEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> occurredAt = const Value.absent(),
                Value<String> dayStartDate = const Value.absent(),
                Value<String> packageName = const Value.absent(),
                Value<String> intentionName = const Value.absent(),
              }) => IntentionUsageEventsCompanion(
                id: id,
                occurredAt: occurredAt,
                dayStartDate: dayStartDate,
                packageName: packageName,
                intentionName: intentionName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int occurredAt,
                required String dayStartDate,
                required String packageName,
                required String intentionName,
              }) => IntentionUsageEventsCompanion.insert(
                id: id,
                occurredAt: occurredAt,
                dayStartDate: dayStartDate,
                packageName: packageName,
                intentionName: intentionName,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IntentionUsageEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IntentionUsageEventsTable,
      IntentionUsageEvent,
      $$IntentionUsageEventsTableFilterComposer,
      $$IntentionUsageEventsTableOrderingComposer,
      $$IntentionUsageEventsTableAnnotationComposer,
      $$IntentionUsageEventsTableCreateCompanionBuilder,
      $$IntentionUsageEventsTableUpdateCompanionBuilder,
      (
        IntentionUsageEvent,
        BaseReferences<
          _$AppDatabase,
          $IntentionUsageEventsTable,
          IntentionUsageEvent
        >,
      ),
      IntentionUsageEvent,
      PrefetchHooks Function()
    >;
typedef $$FocusUsageEventsTableCreateCompanionBuilder =
    FocusUsageEventsCompanion Function({
      Value<int> id,
      required int occurredAt,
      required String dayStartDate,
      required int durationInMs,
    });
typedef $$FocusUsageEventsTableUpdateCompanionBuilder =
    FocusUsageEventsCompanion Function({
      Value<int> id,
      Value<int> occurredAt,
      Value<String> dayStartDate,
      Value<int> durationInMs,
    });

class $$FocusUsageEventsTableFilterComposer
    extends Composer<_$AppDatabase, $FocusUsageEventsTable> {
  $$FocusUsageEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayStartDate => $composableBuilder(
    column: $table.dayStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationInMs => $composableBuilder(
    column: $table.durationInMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FocusUsageEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $FocusUsageEventsTable> {
  $$FocusUsageEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayStartDate => $composableBuilder(
    column: $table.dayStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationInMs => $composableBuilder(
    column: $table.durationInMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FocusUsageEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FocusUsageEventsTable> {
  $$FocusUsageEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dayStartDate => $composableBuilder(
    column: $table.dayStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationInMs => $composableBuilder(
    column: $table.durationInMs,
    builder: (column) => column,
  );
}

class $$FocusUsageEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FocusUsageEventsTable,
          FocusUsageEvent,
          $$FocusUsageEventsTableFilterComposer,
          $$FocusUsageEventsTableOrderingComposer,
          $$FocusUsageEventsTableAnnotationComposer,
          $$FocusUsageEventsTableCreateCompanionBuilder,
          $$FocusUsageEventsTableUpdateCompanionBuilder,
          (
            FocusUsageEvent,
            BaseReferences<
              _$AppDatabase,
              $FocusUsageEventsTable,
              FocusUsageEvent
            >,
          ),
          FocusUsageEvent,
          PrefetchHooks Function()
        > {
  $$FocusUsageEventsTableTableManager(
    _$AppDatabase db,
    $FocusUsageEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusUsageEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusUsageEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusUsageEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> occurredAt = const Value.absent(),
                Value<String> dayStartDate = const Value.absent(),
                Value<int> durationInMs = const Value.absent(),
              }) => FocusUsageEventsCompanion(
                id: id,
                occurredAt: occurredAt,
                dayStartDate: dayStartDate,
                durationInMs: durationInMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int occurredAt,
                required String dayStartDate,
                required int durationInMs,
              }) => FocusUsageEventsCompanion.insert(
                id: id,
                occurredAt: occurredAt,
                dayStartDate: dayStartDate,
                durationInMs: durationInMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FocusUsageEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FocusUsageEventsTable,
      FocusUsageEvent,
      $$FocusUsageEventsTableFilterComposer,
      $$FocusUsageEventsTableOrderingComposer,
      $$FocusUsageEventsTableAnnotationComposer,
      $$FocusUsageEventsTableCreateCompanionBuilder,
      $$FocusUsageEventsTableUpdateCompanionBuilder,
      (
        FocusUsageEvent,
        BaseReferences<_$AppDatabase, $FocusUsageEventsTable, FocusUsageEvent>,
      ),
      FocusUsageEvent,
      PrefetchHooks Function()
    >;
typedef $$FavoritesTableCreateCompanionBuilder =
    FavoritesCompanion Function({
      Value<int> id,
      required String packageName,
      required int orderIndex,
    });
typedef $$FavoritesTableUpdateCompanionBuilder =
    FavoritesCompanion Function({
      Value<int> id,
      Value<String> packageName,
      Value<int> orderIndex,
    });

final class $$FavoritesTableReferences
    extends BaseReferences<_$AppDatabase, $FavoritesTable, Favorite> {
  $$FavoritesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ApplicationsTable _packageNameTable(_$AppDatabase db) =>
      db.applications.createAlias(
        $_aliasNameGenerator(
          db.favorites.packageName,
          db.applications.packageName,
        ),
      );

  $$ApplicationsTableProcessedTableManager get packageName {
    final $_column = $_itemColumn<String>('package_name')!;

    final manager = $$ApplicationsTableTableManager(
      $_db,
      $_db.applications,
    ).filter((f) => f.packageName.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_packageNameTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$ApplicationsTableFilterComposer get packageName {
    final $$ApplicationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packageName,
      referencedTable: $db.applications,
      getReferencedColumn: (t) => t.packageName,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationsTableFilterComposer(
            $db: $db,
            $table: $db.applications,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$ApplicationsTableOrderingComposer get packageName {
    final $$ApplicationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packageName,
      referencedTable: $db.applications,
      getReferencedColumn: (t) => t.packageName,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationsTableOrderingComposer(
            $db: $db,
            $table: $db.applications,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  $$ApplicationsTableAnnotationComposer get packageName {
    final $$ApplicationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packageName,
      referencedTable: $db.applications,
      getReferencedColumn: (t) => t.packageName,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationsTableAnnotationComposer(
            $db: $db,
            $table: $db.applications,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          Favorite,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (Favorite, $$FavoritesTableReferences),
          Favorite,
          PrefetchHooks Function({bool packageName})
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> packageName = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
              }) => FavoritesCompanion(
                id: id,
                packageName: packageName,
                orderIndex: orderIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String packageName,
                required int orderIndex,
              }) => FavoritesCompanion.insert(
                id: id,
                packageName: packageName,
                orderIndex: orderIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FavoritesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({packageName = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (packageName) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.packageName,
                                referencedTable: $$FavoritesTableReferences
                                    ._packageNameTable(db),
                                referencedColumn: $$FavoritesTableReferences
                                    ._packageNameTable(db)
                                    .packageName,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      Favorite,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (Favorite, $$FavoritesTableReferences),
      Favorite,
      PrefetchHooks Function({bool packageName})
    >;
typedef $$AchievementsUnlockedTableCreateCompanionBuilder =
    AchievementsUnlockedCompanion Function({
      required String id,
      required int unlockedAt,
      Value<int> rowid,
    });
typedef $$AchievementsUnlockedTableUpdateCompanionBuilder =
    AchievementsUnlockedCompanion Function({
      Value<String> id,
      Value<int> unlockedAt,
      Value<int> rowid,
    });

class $$AchievementsUnlockedTableFilterComposer
    extends Composer<_$AppDatabase, $AchievementsUnlockedTable> {
  $$AchievementsUnlockedTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AchievementsUnlockedTableOrderingComposer
    extends Composer<_$AppDatabase, $AchievementsUnlockedTable> {
  $$AchievementsUnlockedTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AchievementsUnlockedTableAnnotationComposer
    extends Composer<_$AppDatabase, $AchievementsUnlockedTable> {
  $$AchievementsUnlockedTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => column,
  );
}

class $$AchievementsUnlockedTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AchievementsUnlockedTable,
          AchievementsUnlockedData,
          $$AchievementsUnlockedTableFilterComposer,
          $$AchievementsUnlockedTableOrderingComposer,
          $$AchievementsUnlockedTableAnnotationComposer,
          $$AchievementsUnlockedTableCreateCompanionBuilder,
          $$AchievementsUnlockedTableUpdateCompanionBuilder,
          (
            AchievementsUnlockedData,
            BaseReferences<
              _$AppDatabase,
              $AchievementsUnlockedTable,
              AchievementsUnlockedData
            >,
          ),
          AchievementsUnlockedData,
          PrefetchHooks Function()
        > {
  $$AchievementsUnlockedTableTableManager(
    _$AppDatabase db,
    $AchievementsUnlockedTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AchievementsUnlockedTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AchievementsUnlockedTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AchievementsUnlockedTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> unlockedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AchievementsUnlockedCompanion(
                id: id,
                unlockedAt: unlockedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int unlockedAt,
                Value<int> rowid = const Value.absent(),
              }) => AchievementsUnlockedCompanion.insert(
                id: id,
                unlockedAt: unlockedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AchievementsUnlockedTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AchievementsUnlockedTable,
      AchievementsUnlockedData,
      $$AchievementsUnlockedTableFilterComposer,
      $$AchievementsUnlockedTableOrderingComposer,
      $$AchievementsUnlockedTableAnnotationComposer,
      $$AchievementsUnlockedTableCreateCompanionBuilder,
      $$AchievementsUnlockedTableUpdateCompanionBuilder,
      (
        AchievementsUnlockedData,
        BaseReferences<
          _$AppDatabase,
          $AchievementsUnlockedTable,
          AchievementsUnlockedData
        >,
      ),
      AchievementsUnlockedData,
      PrefetchHooks Function()
    >;
typedef $$StreakStateTableCreateCompanionBuilder =
    StreakStateCompanion Function({
      required String id,
      Value<int> currentCount,
      Value<int> longest,
      Value<String?> lastIncrementedDay,
      Value<int> rowid,
    });
typedef $$StreakStateTableUpdateCompanionBuilder =
    StreakStateCompanion Function({
      Value<String> id,
      Value<int> currentCount,
      Value<int> longest,
      Value<String?> lastIncrementedDay,
      Value<int> rowid,
    });

class $$StreakStateTableFilterComposer
    extends Composer<_$AppDatabase, $StreakStateTable> {
  $$StreakStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentCount => $composableBuilder(
    column: $table.currentCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get longest => $composableBuilder(
    column: $table.longest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastIncrementedDay => $composableBuilder(
    column: $table.lastIncrementedDay,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StreakStateTableOrderingComposer
    extends Composer<_$AppDatabase, $StreakStateTable> {
  $$StreakStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentCount => $composableBuilder(
    column: $table.currentCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get longest => $composableBuilder(
    column: $table.longest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastIncrementedDay => $composableBuilder(
    column: $table.lastIncrementedDay,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StreakStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $StreakStateTable> {
  $$StreakStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get currentCount => $composableBuilder(
    column: $table.currentCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get longest =>
      $composableBuilder(column: $table.longest, builder: (column) => column);

  GeneratedColumn<String> get lastIncrementedDay => $composableBuilder(
    column: $table.lastIncrementedDay,
    builder: (column) => column,
  );
}

class $$StreakStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StreakStateTable,
          StreakStateData,
          $$StreakStateTableFilterComposer,
          $$StreakStateTableOrderingComposer,
          $$StreakStateTableAnnotationComposer,
          $$StreakStateTableCreateCompanionBuilder,
          $$StreakStateTableUpdateCompanionBuilder,
          (
            StreakStateData,
            BaseReferences<_$AppDatabase, $StreakStateTable, StreakStateData>,
          ),
          StreakStateData,
          PrefetchHooks Function()
        > {
  $$StreakStateTableTableManager(_$AppDatabase db, $StreakStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StreakStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StreakStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StreakStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> currentCount = const Value.absent(),
                Value<int> longest = const Value.absent(),
                Value<String?> lastIncrementedDay = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StreakStateCompanion(
                id: id,
                currentCount: currentCount,
                longest: longest,
                lastIncrementedDay: lastIncrementedDay,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> currentCount = const Value.absent(),
                Value<int> longest = const Value.absent(),
                Value<String?> lastIncrementedDay = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StreakStateCompanion.insert(
                id: id,
                currentCount: currentCount,
                longest: longest,
                lastIncrementedDay: lastIncrementedDay,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StreakStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StreakStateTable,
      StreakStateData,
      $$StreakStateTableFilterComposer,
      $$StreakStateTableOrderingComposer,
      $$StreakStateTableAnnotationComposer,
      $$StreakStateTableCreateCompanionBuilder,
      $$StreakStateTableUpdateCompanionBuilder,
      (
        StreakStateData,
        BaseReferences<_$AppDatabase, $StreakStateTable, StreakStateData>,
      ),
      StreakStateData,
      PrefetchHooks Function()
    >;
typedef $$JournalEntriesTableCreateCompanionBuilder =
    JournalEntriesCompanion Function({
      required String dayStartDate,
      required int createdAt,
      required int updatedAt,
      required String body,
      Value<int> rowid,
    });
typedef $$JournalEntriesTableUpdateCompanionBuilder =
    JournalEntriesCompanion Function({
      Value<String> dayStartDate,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> body,
      Value<int> rowid,
    });

class $$JournalEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dayStartDate => $composableBuilder(
    column: $table.dayStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JournalEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dayStartDate => $composableBuilder(
    column: $table.dayStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JournalEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dayStartDate => $composableBuilder(
    column: $table.dayStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);
}

class $$JournalEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JournalEntriesTable,
          JournalEntry,
          $$JournalEntriesTableFilterComposer,
          $$JournalEntriesTableOrderingComposer,
          $$JournalEntriesTableAnnotationComposer,
          $$JournalEntriesTableCreateCompanionBuilder,
          $$JournalEntriesTableUpdateCompanionBuilder,
          (
            JournalEntry,
            BaseReferences<_$AppDatabase, $JournalEntriesTable, JournalEntry>,
          ),
          JournalEntry,
          PrefetchHooks Function()
        > {
  $$JournalEntriesTableTableManager(
    _$AppDatabase db,
    $JournalEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JournalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JournalEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JournalEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> dayStartDate = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion(
                dayStartDate: dayStartDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                body: body,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dayStartDate,
                required int createdAt,
                required int updatedAt,
                required String body,
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion.insert(
                dayStartDate: dayStartDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                body: body,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JournalEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JournalEntriesTable,
      JournalEntry,
      $$JournalEntriesTableFilterComposer,
      $$JournalEntriesTableOrderingComposer,
      $$JournalEntriesTableAnnotationComposer,
      $$JournalEntriesTableCreateCompanionBuilder,
      $$JournalEntriesTableUpdateCompanionBuilder,
      (
        JournalEntry,
        BaseReferences<_$AppDatabase, $JournalEntriesTable, JournalEntry>,
      ),
      JournalEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$ApplicationsTableTableManager get applications =>
      $$ApplicationsTableTableManager(_db, _db.applications);
  $$AppProfileRelationsTableTableManager get appProfileRelations =>
      $$AppProfileRelationsTableTableManager(_db, _db.appProfileRelations);
  $$WebsiteRulesTableTableManager get websiteRules =>
      $$WebsiteRulesTableTableManager(_db, _db.websiteRules);
  $$IntervalsTableTableManager get intervals =>
      $$IntervalsTableTableManager(_db, _db.intervals);
  $$UsageLimitsTableTableManager get usageLimits =>
      $$UsageLimitsTableTableManager(_db, _db.usageLimits);
  $$GeoAddressesTableTableManager get geoAddresses =>
      $$GeoAddressesTableTableManager(_db, _db.geoAddresses);
  $$WifiNetworksTableTableManager get wifiNetworks =>
      $$WifiNetworksTableTableManager(_db, _db.wifiNetworks);
  $$BlockSessionsTableTableManager get blockSessions =>
      $$BlockSessionsTableTableManager(_db, _db.blockSessions);
  $$BrowserConfigsTableTableManager get browserConfigs =>
      $$BrowserConfigsTableTableManager(_db, _db.browserConfigs);
  $$AdultContentSitesTableTableManager get adultContentSites =>
      $$AdultContentSitesTableTableManager(_db, _db.adultContentSites);
  $$PomodoroSessionsTableTableManager get pomodoroSessions =>
      $$PomodoroSessionsTableTableManager(_db, _db.pomodoroSessions);
  $$BlockingConfigsTableTableManager get blockingConfigs =>
      $$BlockingConfigsTableTableManager(_db, _db.blockingConfigs);
  $$MoodCheckInsTableTableManager get moodCheckIns =>
      $$MoodCheckInsTableTableManager(_db, _db.moodCheckIns);
  $$EmergencyUnblocksTableTableManager get emergencyUnblocks =>
      $$EmergencyUnblocksTableTableManager(_db, _db.emergencyUnblocks);
  $$UsedBackdoorCodesTableTableManager get usedBackdoorCodes =>
      $$UsedBackdoorCodesTableTableManager(_db, _db.usedBackdoorCodes);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$RestrictedAccessEventsTableTableManager get restrictedAccessEvents =>
      $$RestrictedAccessEventsTableTableManager(
        _db,
        _db.restrictedAccessEvents,
      );
  $$IntentionUsageEventsTableTableManager get intentionUsageEvents =>
      $$IntentionUsageEventsTableTableManager(_db, _db.intentionUsageEvents);
  $$FocusUsageEventsTableTableManager get focusUsageEvents =>
      $$FocusUsageEventsTableTableManager(_db, _db.focusUsageEvents);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$AchievementsUnlockedTableTableManager get achievementsUnlocked =>
      $$AchievementsUnlockedTableTableManager(_db, _db.achievementsUnlocked);
  $$StreakStateTableTableManager get streakState =>
      $$StreakStateTableTableManager(_db, _db.streakState);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(_db, _db.journalEntries);
}
