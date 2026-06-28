// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AccountProvider, String>
  provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<AccountProvider>($AccountsTable.$converterprovider);
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
  late final GeneratedColumnWithTypeConverter<BackupTarget, String>
  backupTarget = GeneratedColumn<String>(
    'backup_target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  ).withConverter<BackupTarget>($AccountsTable.$converterbackupTarget);
  static const VerificationMeta _lastBackupAtMeta = const VerificationMeta(
    'lastBackupAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastBackupAt = GeneratedColumn<DateTime>(
    'last_backup_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    provider,
    displayName,
    backupTarget,
    lastBackupAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('last_backup_at')) {
      context.handle(
        _lastBackupAtMeta,
        lastBackupAt.isAcceptableOrUnknown(
          data['last_backup_at']!,
          _lastBackupAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      provider: $AccountsTable.$converterprovider.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}provider'],
        )!,
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      backupTarget: $AccountsTable.$converterbackupTarget.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}backup_target'],
        )!,
      ),
      lastBackupAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_backup_at'],
      ),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AccountProvider, String, String>
  $converterprovider = const EnumNameConverter<AccountProvider>(
    AccountProvider.values,
  );
  static JsonTypeConverter2<BackupTarget, String, String>
  $converterbackupTarget = const EnumNameConverter<BackupTarget>(
    BackupTarget.values,
  );
}

class Account extends DataClass implements Insertable<Account> {
  final String id;
  final AccountProvider provider;
  final String? displayName;
  final BackupTarget backupTarget;
  final DateTime? lastBackupAt;
  const Account({
    required this.id,
    required this.provider,
    this.displayName,
    required this.backupTarget,
    this.lastBackupAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['provider'] = Variable<String>(
        $AccountsTable.$converterprovider.toSql(provider),
      );
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    {
      map['backup_target'] = Variable<String>(
        $AccountsTable.$converterbackupTarget.toSql(backupTarget),
      );
    }
    if (!nullToAbsent || lastBackupAt != null) {
      map['last_backup_at'] = Variable<DateTime>(lastBackupAt);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      provider: Value(provider),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      backupTarget: Value(backupTarget),
      lastBackupAt: lastBackupAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastBackupAt),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<String>(json['id']),
      provider: $AccountsTable.$converterprovider.fromJson(
        serializer.fromJson<String>(json['provider']),
      ),
      displayName: serializer.fromJson<String?>(json['displayName']),
      backupTarget: $AccountsTable.$converterbackupTarget.fromJson(
        serializer.fromJson<String>(json['backupTarget']),
      ),
      lastBackupAt: serializer.fromJson<DateTime?>(json['lastBackupAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'provider': serializer.toJson<String>(
        $AccountsTable.$converterprovider.toJson(provider),
      ),
      'displayName': serializer.toJson<String?>(displayName),
      'backupTarget': serializer.toJson<String>(
        $AccountsTable.$converterbackupTarget.toJson(backupTarget),
      ),
      'lastBackupAt': serializer.toJson<DateTime?>(lastBackupAt),
    };
  }

  Account copyWith({
    String? id,
    AccountProvider? provider,
    Value<String?> displayName = const Value.absent(),
    BackupTarget? backupTarget,
    Value<DateTime?> lastBackupAt = const Value.absent(),
  }) => Account(
    id: id ?? this.id,
    provider: provider ?? this.provider,
    displayName: displayName.present ? displayName.value : this.displayName,
    backupTarget: backupTarget ?? this.backupTarget,
    lastBackupAt: lastBackupAt.present ? lastBackupAt.value : this.lastBackupAt,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      provider: data.provider.present ? data.provider.value : this.provider,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      backupTarget: data.backupTarget.present
          ? data.backupTarget.value
          : this.backupTarget,
      lastBackupAt: data.lastBackupAt.present
          ? data.lastBackupAt.value
          : this.lastBackupAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('displayName: $displayName, ')
          ..write('backupTarget: $backupTarget, ')
          ..write('lastBackupAt: $lastBackupAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, provider, displayName, backupTarget, lastBackupAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.provider == this.provider &&
          other.displayName == this.displayName &&
          other.backupTarget == this.backupTarget &&
          other.lastBackupAt == this.lastBackupAt);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> id;
  final Value<AccountProvider> provider;
  final Value<String?> displayName;
  final Value<BackupTarget> backupTarget;
  final Value<DateTime?> lastBackupAt;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.provider = const Value.absent(),
    this.displayName = const Value.absent(),
    this.backupTarget = const Value.absent(),
    this.lastBackupAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required AccountProvider provider,
    this.displayName = const Value.absent(),
    this.backupTarget = const Value.absent(),
    this.lastBackupAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       provider = Value(provider);
  static Insertable<Account> custom({
    Expression<String>? id,
    Expression<String>? provider,
    Expression<String>? displayName,
    Expression<String>? backupTarget,
    Expression<DateTime>? lastBackupAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (provider != null) 'provider': provider,
      if (displayName != null) 'display_name': displayName,
      if (backupTarget != null) 'backup_target': backupTarget,
      if (lastBackupAt != null) 'last_backup_at': lastBackupAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<AccountProvider>? provider,
    Value<String?>? displayName,
    Value<BackupTarget>? backupTarget,
    Value<DateTime?>? lastBackupAt,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      displayName: displayName ?? this.displayName,
      backupTarget: backupTarget ?? this.backupTarget,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(
        $AccountsTable.$converterprovider.toSql(provider.value),
      );
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (backupTarget.present) {
      map['backup_target'] = Variable<String>(
        $AccountsTable.$converterbackupTarget.toSql(backupTarget.value),
      );
    }
    if (lastBackupAt.present) {
      map['last_backup_at'] = Variable<DateTime>(lastBackupAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('displayName: $displayName, ')
          ..write('backupTarget: $backupTarget, ')
          ..write('lastBackupAt: $lastBackupAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ScheduleType, String>
  scheduleType = GeneratedColumn<String>(
    'schedule_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ScheduleType>($ProjectsTable.$converterscheduleType);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
  scheduleConfig =
      GeneratedColumn<String>(
        'schedule_config',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      ).withConverter<Map<String, dynamic>>(
        $ProjectsTable.$converterscheduleConfig,
      );
  static const VerificationMeta _coverPhotoIdMeta = const VerificationMeta(
    'coverPhotoId',
  );
  @override
  late final GeneratedColumn<String> coverPhotoId = GeneratedColumn<String>(
    'cover_photo_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EventPeg, String> eventPeg =
      GeneratedColumn<String>(
        'event_peg',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('none'),
      ).withConverter<EventPeg>($ProjectsTable.$convertereventPeg);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    scheduleType,
    scheduleConfig,
    coverPhotoId,
    eventPeg,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('cover_photo_id')) {
      context.handle(
        _coverPhotoIdMeta,
        coverPhotoId.isAcceptableOrUnknown(
          data['cover_photo_id']!,
          _coverPhotoIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      scheduleType: $ProjectsTable.$converterscheduleType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}schedule_type'],
        )!,
      ),
      scheduleConfig: $ProjectsTable.$converterscheduleConfig.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}schedule_config'],
        )!,
      ),
      coverPhotoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_photo_id'],
      ),
      eventPeg: $ProjectsTable.$convertereventPeg.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}event_peg'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ScheduleType, String, String>
  $converterscheduleType = const EnumNameConverter<ScheduleType>(
    ScheduleType.values,
  );
  static TypeConverter<Map<String, dynamic>, String> $converterscheduleConfig =
      const JsonMapConverter();
  static JsonTypeConverter2<EventPeg, String, String> $convertereventPeg =
      const EnumNameConverter<EventPeg>(EventPeg.values);
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String title;
  final ScheduleType scheduleType;

  /// 주기 유형별 상세(2장 "촬영 주기 설정"). 예: {"weekday":6,"time":"10:00"}.
  final Map<String, dynamic> scheduleConfig;
  final String? coverPhotoId;
  final EventPeg eventPeg;
  final DateTime createdAt;
  const Project({
    required this.id,
    required this.title,
    required this.scheduleType,
    required this.scheduleConfig,
    this.coverPhotoId,
    required this.eventPeg,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    {
      map['schedule_type'] = Variable<String>(
        $ProjectsTable.$converterscheduleType.toSql(scheduleType),
      );
    }
    {
      map['schedule_config'] = Variable<String>(
        $ProjectsTable.$converterscheduleConfig.toSql(scheduleConfig),
      );
    }
    if (!nullToAbsent || coverPhotoId != null) {
      map['cover_photo_id'] = Variable<String>(coverPhotoId);
    }
    {
      map['event_peg'] = Variable<String>(
        $ProjectsTable.$convertereventPeg.toSql(eventPeg),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      title: Value(title),
      scheduleType: Value(scheduleType),
      scheduleConfig: Value(scheduleConfig),
      coverPhotoId: coverPhotoId == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPhotoId),
      eventPeg: Value(eventPeg),
      createdAt: Value(createdAt),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      scheduleType: $ProjectsTable.$converterscheduleType.fromJson(
        serializer.fromJson<String>(json['scheduleType']),
      ),
      scheduleConfig: serializer.fromJson<Map<String, dynamic>>(
        json['scheduleConfig'],
      ),
      coverPhotoId: serializer.fromJson<String?>(json['coverPhotoId']),
      eventPeg: $ProjectsTable.$convertereventPeg.fromJson(
        serializer.fromJson<String>(json['eventPeg']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'scheduleType': serializer.toJson<String>(
        $ProjectsTable.$converterscheduleType.toJson(scheduleType),
      ),
      'scheduleConfig': serializer.toJson<Map<String, dynamic>>(scheduleConfig),
      'coverPhotoId': serializer.toJson<String?>(coverPhotoId),
      'eventPeg': serializer.toJson<String>(
        $ProjectsTable.$convertereventPeg.toJson(eventPeg),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Project copyWith({
    String? id,
    String? title,
    ScheduleType? scheduleType,
    Map<String, dynamic>? scheduleConfig,
    Value<String?> coverPhotoId = const Value.absent(),
    EventPeg? eventPeg,
    DateTime? createdAt,
  }) => Project(
    id: id ?? this.id,
    title: title ?? this.title,
    scheduleType: scheduleType ?? this.scheduleType,
    scheduleConfig: scheduleConfig ?? this.scheduleConfig,
    coverPhotoId: coverPhotoId.present ? coverPhotoId.value : this.coverPhotoId,
    eventPeg: eventPeg ?? this.eventPeg,
    createdAt: createdAt ?? this.createdAt,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      scheduleType: data.scheduleType.present
          ? data.scheduleType.value
          : this.scheduleType,
      scheduleConfig: data.scheduleConfig.present
          ? data.scheduleConfig.value
          : this.scheduleConfig,
      coverPhotoId: data.coverPhotoId.present
          ? data.coverPhotoId.value
          : this.coverPhotoId,
      eventPeg: data.eventPeg.present ? data.eventPeg.value : this.eventPeg,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('scheduleType: $scheduleType, ')
          ..write('scheduleConfig: $scheduleConfig, ')
          ..write('coverPhotoId: $coverPhotoId, ')
          ..write('eventPeg: $eventPeg, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    scheduleType,
    scheduleConfig,
    coverPhotoId,
    eventPeg,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.title == this.title &&
          other.scheduleType == this.scheduleType &&
          other.scheduleConfig == this.scheduleConfig &&
          other.coverPhotoId == this.coverPhotoId &&
          other.eventPeg == this.eventPeg &&
          other.createdAt == this.createdAt);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> title;
  final Value<ScheduleType> scheduleType;
  final Value<Map<String, dynamic>> scheduleConfig;
  final Value<String?> coverPhotoId;
  final Value<EventPeg> eventPeg;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.scheduleType = const Value.absent(),
    this.scheduleConfig = const Value.absent(),
    this.coverPhotoId = const Value.absent(),
    this.eventPeg = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String title,
    required ScheduleType scheduleType,
    this.scheduleConfig = const Value.absent(),
    this.coverPhotoId = const Value.absent(),
    this.eventPeg = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       scheduleType = Value(scheduleType);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? scheduleType,
    Expression<String>? scheduleConfig,
    Expression<String>? coverPhotoId,
    Expression<String>? eventPeg,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (scheduleType != null) 'schedule_type': scheduleType,
      if (scheduleConfig != null) 'schedule_config': scheduleConfig,
      if (coverPhotoId != null) 'cover_photo_id': coverPhotoId,
      if (eventPeg != null) 'event_peg': eventPeg,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<ScheduleType>? scheduleType,
    Value<Map<String, dynamic>>? scheduleConfig,
    Value<String?>? coverPhotoId,
    Value<EventPeg>? eventPeg,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduleType: scheduleType ?? this.scheduleType,
      scheduleConfig: scheduleConfig ?? this.scheduleConfig,
      coverPhotoId: coverPhotoId ?? this.coverPhotoId,
      eventPeg: eventPeg ?? this.eventPeg,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (scheduleType.present) {
      map['schedule_type'] = Variable<String>(
        $ProjectsTable.$converterscheduleType.toSql(scheduleType.value),
      );
    }
    if (scheduleConfig.present) {
      map['schedule_config'] = Variable<String>(
        $ProjectsTable.$converterscheduleConfig.toSql(scheduleConfig.value),
      );
    }
    if (coverPhotoId.present) {
      map['cover_photo_id'] = Variable<String>(coverPhotoId.value);
    }
    if (eventPeg.present) {
      map['event_peg'] = Variable<String>(
        $ProjectsTable.$convertereventPeg.toSql(eventPeg.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('scheduleType: $scheduleType, ')
          ..write('scheduleConfig: $scheduleConfig, ')
          ..write('coverPhotoId: $coverPhotoId, ')
          ..write('eventPeg: $eventPeg, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MembersTable extends Members with TableInfo<$MembersTable, Member> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
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
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, projectId, name, role];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'members';
  @override
  VerificationContext validateIntegrity(
    Insertable<Member> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Member map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Member(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      ),
    );
  }

  @override
  $MembersTable createAlias(String alias) {
    return $MembersTable(attachedDatabase, alias);
  }
}

class Member extends DataClass implements Insertable<Member> {
  final String id;
  final String projectId;
  final String name;
  final String? role;
  const Member({
    required this.id,
    required this.projectId,
    required this.name,
    this.role,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(role);
    }
    return map;
  }

  MembersCompanion toCompanion(bool nullToAbsent) {
    return MembersCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: Value(name),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
    );
  }

  factory Member.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Member(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      name: serializer.fromJson<String>(json['name']),
      role: serializer.fromJson<String?>(json['role']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'name': serializer.toJson<String>(name),
      'role': serializer.toJson<String?>(role),
    };
  }

  Member copyWith({
    String? id,
    String? projectId,
    String? name,
    Value<String?> role = const Value.absent(),
  }) => Member(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    name: name ?? this.name,
    role: role.present ? role.value : this.role,
  );
  Member copyWithCompanion(MembersCompanion data) {
    return Member(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      role: data.role.present ? data.role.value : this.role,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Member(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('role: $role')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, name, role);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Member &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.role == this.role);
}

class MembersCompanion extends UpdateCompanion<Member> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> name;
  final Value<String?> role;
  final Value<int> rowid;
  const MembersCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.role = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MembersCompanion.insert({
    required String id,
    required String projectId,
    required String name,
    this.role = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       name = Value(name);
  static Insertable<Member> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? name,
    Expression<String>? role,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (role != null) 'role': role,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MembersCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? name,
    Value<String?>? role,
    Value<int>? rowid,
  }) {
    return MembersCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      role: role ?? this.role,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MembersCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('role: $role, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlacesTable extends Places with TableInfo<$PlacesTable, Place> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _radiusMMeta = const VerificationMeta(
    'radiusM',
  );
  @override
  late final GeneratedColumn<int> radiusM = GeneratedColumn<int>(
    'radius_m',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(200),
  );
  static const VerificationMeta _captureCountMeta = const VerificationMeta(
    'captureCount',
  );
  @override
  late final GeneratedColumn<int> captureCount = GeneratedColumn<int>(
    'capture_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _geofenceEnabledMeta = const VerificationMeta(
    'geofenceEnabled',
  );
  @override
  late final GeneratedColumn<bool> geofenceEnabled = GeneratedColumn<bool>(
    'geofence_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("geofence_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    label,
    latitude,
    longitude,
    radiusM,
    captureCount,
    geofenceEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'places';
  @override
  VerificationContext validateIntegrity(
    Insertable<Place> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
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
    if (data.containsKey('radius_m')) {
      context.handle(
        _radiusMMeta,
        radiusM.isAcceptableOrUnknown(data['radius_m']!, _radiusMMeta),
      );
    }
    if (data.containsKey('capture_count')) {
      context.handle(
        _captureCountMeta,
        captureCount.isAcceptableOrUnknown(
          data['capture_count']!,
          _captureCountMeta,
        ),
      );
    }
    if (data.containsKey('geofence_enabled')) {
      context.handle(
        _geofenceEnabledMeta,
        geofenceEnabled.isAcceptableOrUnknown(
          data['geofence_enabled']!,
          _geofenceEnabledMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Place map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Place(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      radiusM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}radius_m'],
      )!,
      captureCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}capture_count'],
      )!,
      geofenceEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}geofence_enabled'],
      )!,
    );
  }

  @override
  $PlacesTable createAlias(String alias) {
    return $PlacesTable(attachedDatabase, alias);
  }
}

class Place extends DataClass implements Insertable<Place> {
  final String id;
  final String projectId;
  final String label;
  final double latitude;
  final double longitude;
  final int radiusM;
  final int captureCount;
  final bool geofenceEnabled;
  const Place({
    required this.id,
    required this.projectId,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.captureCount,
    required this.geofenceEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['label'] = Variable<String>(label);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['radius_m'] = Variable<int>(radiusM);
    map['capture_count'] = Variable<int>(captureCount);
    map['geofence_enabled'] = Variable<bool>(geofenceEnabled);
    return map;
  }

  PlacesCompanion toCompanion(bool nullToAbsent) {
    return PlacesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      label: Value(label),
      latitude: Value(latitude),
      longitude: Value(longitude),
      radiusM: Value(radiusM),
      captureCount: Value(captureCount),
      geofenceEnabled: Value(geofenceEnabled),
    );
  }

  factory Place.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Place(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      label: serializer.fromJson<String>(json['label']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      radiusM: serializer.fromJson<int>(json['radiusM']),
      captureCount: serializer.fromJson<int>(json['captureCount']),
      geofenceEnabled: serializer.fromJson<bool>(json['geofenceEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'label': serializer.toJson<String>(label),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'radiusM': serializer.toJson<int>(radiusM),
      'captureCount': serializer.toJson<int>(captureCount),
      'geofenceEnabled': serializer.toJson<bool>(geofenceEnabled),
    };
  }

  Place copyWith({
    String? id,
    String? projectId,
    String? label,
    double? latitude,
    double? longitude,
    int? radiusM,
    int? captureCount,
    bool? geofenceEnabled,
  }) => Place(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    label: label ?? this.label,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radiusM: radiusM ?? this.radiusM,
    captureCount: captureCount ?? this.captureCount,
    geofenceEnabled: geofenceEnabled ?? this.geofenceEnabled,
  );
  Place copyWithCompanion(PlacesCompanion data) {
    return Place(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      label: data.label.present ? data.label.value : this.label,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      radiusM: data.radiusM.present ? data.radiusM.value : this.radiusM,
      captureCount: data.captureCount.present
          ? data.captureCount.value
          : this.captureCount,
      geofenceEnabled: data.geofenceEnabled.present
          ? data.geofenceEnabled.value
          : this.geofenceEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Place(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('label: $label, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radiusM: $radiusM, ')
          ..write('captureCount: $captureCount, ')
          ..write('geofenceEnabled: $geofenceEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    label,
    latitude,
    longitude,
    radiusM,
    captureCount,
    geofenceEnabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Place &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.label == this.label &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.radiusM == this.radiusM &&
          other.captureCount == this.captureCount &&
          other.geofenceEnabled == this.geofenceEnabled);
}

class PlacesCompanion extends UpdateCompanion<Place> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> label;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<int> radiusM;
  final Value<int> captureCount;
  final Value<bool> geofenceEnabled;
  final Value<int> rowid;
  const PlacesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.label = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.radiusM = const Value.absent(),
    this.captureCount = const Value.absent(),
    this.geofenceEnabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlacesCompanion.insert({
    required String id,
    required String projectId,
    required String label,
    required double latitude,
    required double longitude,
    this.radiusM = const Value.absent(),
    this.captureCount = const Value.absent(),
    this.geofenceEnabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       label = Value(label),
       latitude = Value(latitude),
       longitude = Value(longitude);
  static Insertable<Place> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? label,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? radiusM,
    Expression<int>? captureCount,
    Expression<bool>? geofenceEnabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (label != null) 'label': label,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (radiusM != null) 'radius_m': radiusM,
      if (captureCount != null) 'capture_count': captureCount,
      if (geofenceEnabled != null) 'geofence_enabled': geofenceEnabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlacesCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? label,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<int>? radiusM,
    Value<int>? captureCount,
    Value<bool>? geofenceEnabled,
    Value<int>? rowid,
  }) {
    return PlacesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusM: radiusM ?? this.radiusM,
      captureCount: captureCount ?? this.captureCount,
      geofenceEnabled: geofenceEnabled ?? this.geofenceEnabled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (radiusM.present) {
      map['radius_m'] = Variable<int>(radiusM.value);
    }
    if (captureCount.present) {
      map['capture_count'] = Variable<int>(captureCount.value);
    }
    if (geofenceEnabled.present) {
      map['geofence_enabled'] = Variable<bool>(geofenceEnabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlacesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('label: $label, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radiusM: $radiusM, ')
          ..write('captureCount: $captureCount, ')
          ..write('geofenceEnabled: $geofenceEnabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CapturesTable extends Captures with TableInfo<$CapturesTable, Capture> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CapturesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbPathMeta = const VerificationMeta(
    'thumbPath',
  );
  @override
  late final GeneratedColumn<String> thumbPath = GeneratedColumn<String>(
    'thumb_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodLabelMeta = const VerificationMeta(
    'periodLabel',
  );
  @override
  late final GeneratedColumn<String> periodLabel = GeneratedColumn<String>(
    'period_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>?, String>
  alignmentMeta =
      GeneratedColumn<String>(
        'alignment_meta',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Map<String, dynamic>?>(
        $CapturesTable.$converteralignmentMetan,
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
  static const VerificationMeta _placeIdMeta = const VerificationMeta(
    'placeId',
  );
  @override
  late final GeneratedColumn<String> placeId = GeneratedColumn<String>(
    'place_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES places (id) ON DELETE SET NULL',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<BackupState, String> backupState =
      GeneratedColumn<String>(
        'backup_state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('localOnly'),
      ).withConverter<BackupState>($CapturesTable.$converterbackupState);
  static const VerificationMeta _decoratedPathMeta = const VerificationMeta(
    'decoratedPath',
  );
  @override
  late final GeneratedColumn<String> decoratedPath = GeneratedColumn<String>(
    'decorated_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    filePath,
    thumbPath,
    capturedAt,
    periodLabel,
    alignmentMeta,
    note,
    placeId,
    backupState,
    decoratedPath,
    sortIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'captures';
  @override
  VerificationContext validateIntegrity(
    Insertable<Capture> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('thumb_path')) {
      context.handle(
        _thumbPathMeta,
        thumbPath.isAcceptableOrUnknown(data['thumb_path']!, _thumbPathMeta),
      );
    } else if (isInserting) {
      context.missing(_thumbPathMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('period_label')) {
      context.handle(
        _periodLabelMeta,
        periodLabel.isAcceptableOrUnknown(
          data['period_label']!,
          _periodLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_periodLabelMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('place_id')) {
      context.handle(
        _placeIdMeta,
        placeId.isAcceptableOrUnknown(data['place_id']!, _placeIdMeta),
      );
    }
    if (data.containsKey('decorated_path')) {
      context.handle(
        _decoratedPathMeta,
        decoratedPath.isAcceptableOrUnknown(
          data['decorated_path']!,
          _decoratedPathMeta,
        ),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Capture map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Capture(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      thumbPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_path'],
      )!,
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
      periodLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_label'],
      )!,
      alignmentMeta: $CapturesTable.$converteralignmentMetan.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}alignment_meta'],
        ),
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      placeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place_id'],
      ),
      backupState: $CapturesTable.$converterbackupState.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}backup_state'],
        )!,
      ),
      decoratedPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decorated_path'],
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      ),
    );
  }

  @override
  $CapturesTable createAlias(String alias) {
    return $CapturesTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, dynamic>, String> $converteralignmentMeta =
      const JsonMapConverter();
  static TypeConverter<Map<String, dynamic>?, String?>
  $converteralignmentMetan = NullAwareTypeConverter.wrap(
    $converteralignmentMeta,
  );
  static JsonTypeConverter2<BackupState, String, String> $converterbackupState =
      const EnumNameConverter<BackupState>(BackupState.values);
}

class Capture extends DataClass implements Insertable<Capture> {
  final String id;
  final String projectId;

  /// 인쇄 품질 위해 원본은 고해상도 보존, 썸네일과 분리 보관(7-1장).
  final String filePath;
  final String thumbPath;
  final DateTime capturedAt;
  final String periodLabel;

  /// 정렬 보정값(이동/스케일/회전) — 사후 재정렬·타임랩스 흔들림 감소용(4장).
  final Map<String, dynamic>? alignmentMeta;
  final String? note;
  final String? placeId;
  final BackupState backupState;

  /// 꾸미기 결과 이미지 경로(있으면 기록에서 이 버전을 보여줌). 원본(filePath)은
  /// 타임랩스·오버레이용으로 그대로 보존(꾸미기 v3).
  final String? decoratedPath;

  /// 사용자가 그리드에서 직접 정한 표시·재생 순서(작을수록 앞=최신 쪽).
  /// null이면 촬영일 기준 자동 정렬. 길게 눌러 드래그로 재배치하면 채워진다.
  final int? sortIndex;
  const Capture({
    required this.id,
    required this.projectId,
    required this.filePath,
    required this.thumbPath,
    required this.capturedAt,
    required this.periodLabel,
    this.alignmentMeta,
    this.note,
    this.placeId,
    required this.backupState,
    this.decoratedPath,
    this.sortIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['file_path'] = Variable<String>(filePath);
    map['thumb_path'] = Variable<String>(thumbPath);
    map['captured_at'] = Variable<DateTime>(capturedAt);
    map['period_label'] = Variable<String>(periodLabel);
    if (!nullToAbsent || alignmentMeta != null) {
      map['alignment_meta'] = Variable<String>(
        $CapturesTable.$converteralignmentMetan.toSql(alignmentMeta),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || placeId != null) {
      map['place_id'] = Variable<String>(placeId);
    }
    {
      map['backup_state'] = Variable<String>(
        $CapturesTable.$converterbackupState.toSql(backupState),
      );
    }
    if (!nullToAbsent || decoratedPath != null) {
      map['decorated_path'] = Variable<String>(decoratedPath);
    }
    if (!nullToAbsent || sortIndex != null) {
      map['sort_index'] = Variable<int>(sortIndex);
    }
    return map;
  }

  CapturesCompanion toCompanion(bool nullToAbsent) {
    return CapturesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      filePath: Value(filePath),
      thumbPath: Value(thumbPath),
      capturedAt: Value(capturedAt),
      periodLabel: Value(periodLabel),
      alignmentMeta: alignmentMeta == null && nullToAbsent
          ? const Value.absent()
          : Value(alignmentMeta),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      placeId: placeId == null && nullToAbsent
          ? const Value.absent()
          : Value(placeId),
      backupState: Value(backupState),
      decoratedPath: decoratedPath == null && nullToAbsent
          ? const Value.absent()
          : Value(decoratedPath),
      sortIndex: sortIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(sortIndex),
    );
  }

  factory Capture.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Capture(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      thumbPath: serializer.fromJson<String>(json['thumbPath']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      periodLabel: serializer.fromJson<String>(json['periodLabel']),
      alignmentMeta: serializer.fromJson<Map<String, dynamic>?>(
        json['alignmentMeta'],
      ),
      note: serializer.fromJson<String?>(json['note']),
      placeId: serializer.fromJson<String?>(json['placeId']),
      backupState: $CapturesTable.$converterbackupState.fromJson(
        serializer.fromJson<String>(json['backupState']),
      ),
      decoratedPath: serializer.fromJson<String?>(json['decoratedPath']),
      sortIndex: serializer.fromJson<int?>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'filePath': serializer.toJson<String>(filePath),
      'thumbPath': serializer.toJson<String>(thumbPath),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'periodLabel': serializer.toJson<String>(periodLabel),
      'alignmentMeta': serializer.toJson<Map<String, dynamic>?>(alignmentMeta),
      'note': serializer.toJson<String?>(note),
      'placeId': serializer.toJson<String?>(placeId),
      'backupState': serializer.toJson<String>(
        $CapturesTable.$converterbackupState.toJson(backupState),
      ),
      'decoratedPath': serializer.toJson<String?>(decoratedPath),
      'sortIndex': serializer.toJson<int?>(sortIndex),
    };
  }

  Capture copyWith({
    String? id,
    String? projectId,
    String? filePath,
    String? thumbPath,
    DateTime? capturedAt,
    String? periodLabel,
    Value<Map<String, dynamic>?> alignmentMeta = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> placeId = const Value.absent(),
    BackupState? backupState,
    Value<String?> decoratedPath = const Value.absent(),
    Value<int?> sortIndex = const Value.absent(),
  }) => Capture(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    filePath: filePath ?? this.filePath,
    thumbPath: thumbPath ?? this.thumbPath,
    capturedAt: capturedAt ?? this.capturedAt,
    periodLabel: periodLabel ?? this.periodLabel,
    alignmentMeta: alignmentMeta.present
        ? alignmentMeta.value
        : this.alignmentMeta,
    note: note.present ? note.value : this.note,
    placeId: placeId.present ? placeId.value : this.placeId,
    backupState: backupState ?? this.backupState,
    decoratedPath: decoratedPath.present
        ? decoratedPath.value
        : this.decoratedPath,
    sortIndex: sortIndex.present ? sortIndex.value : this.sortIndex,
  );
  Capture copyWithCompanion(CapturesCompanion data) {
    return Capture(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      thumbPath: data.thumbPath.present ? data.thumbPath.value : this.thumbPath,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      periodLabel: data.periodLabel.present
          ? data.periodLabel.value
          : this.periodLabel,
      alignmentMeta: data.alignmentMeta.present
          ? data.alignmentMeta.value
          : this.alignmentMeta,
      note: data.note.present ? data.note.value : this.note,
      placeId: data.placeId.present ? data.placeId.value : this.placeId,
      backupState: data.backupState.present
          ? data.backupState.value
          : this.backupState,
      decoratedPath: data.decoratedPath.present
          ? data.decoratedPath.value
          : this.decoratedPath,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Capture(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('filePath: $filePath, ')
          ..write('thumbPath: $thumbPath, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('periodLabel: $periodLabel, ')
          ..write('alignmentMeta: $alignmentMeta, ')
          ..write('note: $note, ')
          ..write('placeId: $placeId, ')
          ..write('backupState: $backupState, ')
          ..write('decoratedPath: $decoratedPath, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    filePath,
    thumbPath,
    capturedAt,
    periodLabel,
    alignmentMeta,
    note,
    placeId,
    backupState,
    decoratedPath,
    sortIndex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Capture &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.filePath == this.filePath &&
          other.thumbPath == this.thumbPath &&
          other.capturedAt == this.capturedAt &&
          other.periodLabel == this.periodLabel &&
          other.alignmentMeta == this.alignmentMeta &&
          other.note == this.note &&
          other.placeId == this.placeId &&
          other.backupState == this.backupState &&
          other.decoratedPath == this.decoratedPath &&
          other.sortIndex == this.sortIndex);
}

class CapturesCompanion extends UpdateCompanion<Capture> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> filePath;
  final Value<String> thumbPath;
  final Value<DateTime> capturedAt;
  final Value<String> periodLabel;
  final Value<Map<String, dynamic>?> alignmentMeta;
  final Value<String?> note;
  final Value<String?> placeId;
  final Value<BackupState> backupState;
  final Value<String?> decoratedPath;
  final Value<int?> sortIndex;
  final Value<int> rowid;
  const CapturesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.thumbPath = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.periodLabel = const Value.absent(),
    this.alignmentMeta = const Value.absent(),
    this.note = const Value.absent(),
    this.placeId = const Value.absent(),
    this.backupState = const Value.absent(),
    this.decoratedPath = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CapturesCompanion.insert({
    required String id,
    required String projectId,
    required String filePath,
    required String thumbPath,
    required DateTime capturedAt,
    required String periodLabel,
    this.alignmentMeta = const Value.absent(),
    this.note = const Value.absent(),
    this.placeId = const Value.absent(),
    this.backupState = const Value.absent(),
    this.decoratedPath = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       filePath = Value(filePath),
       thumbPath = Value(thumbPath),
       capturedAt = Value(capturedAt),
       periodLabel = Value(periodLabel);
  static Insertable<Capture> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? filePath,
    Expression<String>? thumbPath,
    Expression<DateTime>? capturedAt,
    Expression<String>? periodLabel,
    Expression<String>? alignmentMeta,
    Expression<String>? note,
    Expression<String>? placeId,
    Expression<String>? backupState,
    Expression<String>? decoratedPath,
    Expression<int>? sortIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (filePath != null) 'file_path': filePath,
      if (thumbPath != null) 'thumb_path': thumbPath,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (periodLabel != null) 'period_label': periodLabel,
      if (alignmentMeta != null) 'alignment_meta': alignmentMeta,
      if (note != null) 'note': note,
      if (placeId != null) 'place_id': placeId,
      if (backupState != null) 'backup_state': backupState,
      if (decoratedPath != null) 'decorated_path': decoratedPath,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CapturesCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? filePath,
    Value<String>? thumbPath,
    Value<DateTime>? capturedAt,
    Value<String>? periodLabel,
    Value<Map<String, dynamic>?>? alignmentMeta,
    Value<String?>? note,
    Value<String?>? placeId,
    Value<BackupState>? backupState,
    Value<String?>? decoratedPath,
    Value<int?>? sortIndex,
    Value<int>? rowid,
  }) {
    return CapturesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      filePath: filePath ?? this.filePath,
      thumbPath: thumbPath ?? this.thumbPath,
      capturedAt: capturedAt ?? this.capturedAt,
      periodLabel: periodLabel ?? this.periodLabel,
      alignmentMeta: alignmentMeta ?? this.alignmentMeta,
      note: note ?? this.note,
      placeId: placeId ?? this.placeId,
      backupState: backupState ?? this.backupState,
      decoratedPath: decoratedPath ?? this.decoratedPath,
      sortIndex: sortIndex ?? this.sortIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (thumbPath.present) {
      map['thumb_path'] = Variable<String>(thumbPath.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (periodLabel.present) {
      map['period_label'] = Variable<String>(periodLabel.value);
    }
    if (alignmentMeta.present) {
      map['alignment_meta'] = Variable<String>(
        $CapturesTable.$converteralignmentMetan.toSql(alignmentMeta.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (placeId.present) {
      map['place_id'] = Variable<String>(placeId.value);
    }
    if (backupState.present) {
      map['backup_state'] = Variable<String>(
        $CapturesTable.$converterbackupState.toSql(backupState.value),
      );
    }
    if (decoratedPath.present) {
      map['decorated_path'] = Variable<String>(decoratedPath.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CapturesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('filePath: $filePath, ')
          ..write('thumbPath: $thumbPath, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('periodLabel: $periodLabel, ')
          ..write('alignmentMeta: $alignmentMeta, ')
          ..write('note: $note, ')
          ..write('placeId: $placeId, ')
          ..write('backupState: $backupState, ')
          ..write('decoratedPath: $decoratedPath, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CaptureMembersTable extends CaptureMembers
    with TableInfo<$CaptureMembersTable, CaptureMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaptureMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _captureIdMeta = const VerificationMeta(
    'captureId',
  );
  @override
  late final GeneratedColumn<String> captureId = GeneratedColumn<String>(
    'capture_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES captures (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  @override
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES members (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [captureId, memberId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'capture_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaptureMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('capture_id')) {
      context.handle(
        _captureIdMeta,
        captureId.isAcceptableOrUnknown(data['capture_id']!, _captureIdMeta),
      );
    } else if (isInserting) {
      context.missing(_captureIdMeta);
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memberIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {captureId, memberId};
  @override
  CaptureMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaptureMember(
      captureId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capture_id'],
      )!,
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      )!,
    );
  }

  @override
  $CaptureMembersTable createAlias(String alias) {
    return $CaptureMembersTable(attachedDatabase, alias);
  }
}

class CaptureMember extends DataClass implements Insertable<CaptureMember> {
  final String captureId;
  final String memberId;
  const CaptureMember({required this.captureId, required this.memberId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['capture_id'] = Variable<String>(captureId);
    map['member_id'] = Variable<String>(memberId);
    return map;
  }

  CaptureMembersCompanion toCompanion(bool nullToAbsent) {
    return CaptureMembersCompanion(
      captureId: Value(captureId),
      memberId: Value(memberId),
    );
  }

  factory CaptureMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaptureMember(
      captureId: serializer.fromJson<String>(json['captureId']),
      memberId: serializer.fromJson<String>(json['memberId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'captureId': serializer.toJson<String>(captureId),
      'memberId': serializer.toJson<String>(memberId),
    };
  }

  CaptureMember copyWith({String? captureId, String? memberId}) =>
      CaptureMember(
        captureId: captureId ?? this.captureId,
        memberId: memberId ?? this.memberId,
      );
  CaptureMember copyWithCompanion(CaptureMembersCompanion data) {
    return CaptureMember(
      captureId: data.captureId.present ? data.captureId.value : this.captureId,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaptureMember(')
          ..write('captureId: $captureId, ')
          ..write('memberId: $memberId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(captureId, memberId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaptureMember &&
          other.captureId == this.captureId &&
          other.memberId == this.memberId);
}

class CaptureMembersCompanion extends UpdateCompanion<CaptureMember> {
  final Value<String> captureId;
  final Value<String> memberId;
  final Value<int> rowid;
  const CaptureMembersCompanion({
    this.captureId = const Value.absent(),
    this.memberId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaptureMembersCompanion.insert({
    required String captureId,
    required String memberId,
    this.rowid = const Value.absent(),
  }) : captureId = Value(captureId),
       memberId = Value(memberId);
  static Insertable<CaptureMember> custom({
    Expression<String>? captureId,
    Expression<String>? memberId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (captureId != null) 'capture_id': captureId,
      if (memberId != null) 'member_id': memberId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaptureMembersCompanion copyWith({
    Value<String>? captureId,
    Value<String>? memberId,
    Value<int>? rowid,
  }) {
    return CaptureMembersCompanion(
      captureId: captureId ?? this.captureId,
      memberId: memberId ?? this.memberId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (captureId.present) {
      map['capture_id'] = Variable<String>(captureId.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaptureMembersCompanion(')
          ..write('captureId: $captureId, ')
          ..write('memberId: $memberId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $MembersTable members = $MembersTable(this);
  late final $PlacesTable places = $PlacesTable(this);
  late final $CapturesTable captures = $CapturesTable(this);
  late final $CaptureMembersTable captureMembers = $CaptureMembersTable(this);
  late final Index idxCaptureProjectTime = Index(
    'idx_capture_project_time',
    'CREATE INDEX idx_capture_project_time ON captures (project_id, captured_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    projects,
    members,
    places,
    captures,
    captureMembers,
    idxCaptureProjectTime,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('members', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('places', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('captures', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'places',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('captures', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'captures',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('capture_members', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'members',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('capture_members', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      required String id,
      required AccountProvider provider,
      Value<String?> displayName,
      Value<BackupTarget> backupTarget,
      Value<DateTime?> lastBackupAt,
      Value<int> rowid,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> id,
      Value<AccountProvider> provider,
      Value<String?> displayName,
      Value<BackupTarget> backupTarget,
      Value<DateTime?> lastBackupAt,
      Value<int> rowid,
    });

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<AccountProvider, AccountProvider, String>
  get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BackupTarget, BackupTarget, String>
  get backupTarget => $composableBuilder(
    column: $table.backupTarget,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get lastBackupAt => $composableBuilder(
    column: $table.lastBackupAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
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

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backupTarget => $composableBuilder(
    column: $table.backupTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastBackupAt => $composableBuilder(
    column: $table.lastBackupAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountProvider, String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<BackupTarget, String> get backupTarget =>
      $composableBuilder(
        column: $table.backupTarget,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get lastBackupAt => $composableBuilder(
    column: $table.lastBackupAt,
    builder: (column) => column,
  );
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
          Account,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<AccountProvider> provider = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<BackupTarget> backupTarget = const Value.absent(),
                Value<DateTime?> lastBackupAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                provider: provider,
                displayName: displayName,
                backupTarget: backupTarget,
                lastBackupAt: lastBackupAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required AccountProvider provider,
                Value<String?> displayName = const Value.absent(),
                Value<BackupTarget> backupTarget = const Value.absent(),
                Value<DateTime?> lastBackupAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                provider: provider,
                displayName: displayName,
                backupTarget: backupTarget,
                lastBackupAt: lastBackupAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
      Account,
      PrefetchHooks Function()
    >;
typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      required String id,
      required String title,
      required ScheduleType scheduleType,
      Value<Map<String, dynamic>> scheduleConfig,
      Value<String?> coverPhotoId,
      Value<EventPeg> eventPeg,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<ScheduleType> scheduleType,
      Value<Map<String, dynamic>> scheduleConfig,
      Value<String?> coverPhotoId,
      Value<EventPeg> eventPeg,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MembersTable, List<Member>> _membersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.members,
    aliasName: 'projects__id__members__project_id',
  );

  $$MembersTableProcessedTableManager get membersRefs {
    final manager = $$MembersTableTableManager(
      $_db,
      $_db.members,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_membersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlacesTable, List<Place>> _placesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.places,
    aliasName: 'projects__id__places__project_id',
  );

  $$PlacesTableProcessedTableManager get placesRefs {
    final manager = $$PlacesTableTableManager(
      $_db,
      $_db.places,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_placesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CapturesTable, List<Capture>> _capturesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.captures,
    aliasName: 'projects__id__captures__project_id',
  );

  $$CapturesTableProcessedTableManager get capturesRefs {
    final manager = $$CapturesTableTableManager(
      $_db,
      $_db.captures,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_capturesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ScheduleType, ScheduleType, String>
  get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<
    Map<String, dynamic>,
    Map<String, dynamic>,
    String
  >
  get scheduleConfig => $composableBuilder(
    column: $table.scheduleConfig,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get coverPhotoId => $composableBuilder(
    column: $table.coverPhotoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EventPeg, EventPeg, String> get eventPeg =>
      $composableBuilder(
        column: $table.eventPeg,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> membersRefs(
    Expression<bool> Function($$MembersTableFilterComposer f) f,
  ) {
    final $$MembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableFilterComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> placesRefs(
    Expression<bool> Function($$PlacesTableFilterComposer f) f,
  ) {
    final $$PlacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableFilterComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> capturesRefs(
    Expression<bool> Function($$CapturesTableFilterComposer f) f,
  ) {
    final $$CapturesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.captures,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CapturesTableFilterComposer(
            $db: $db,
            $table: $db.captures,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleConfig => $composableBuilder(
    column: $table.scheduleConfig,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPhotoId => $composableBuilder(
    column: $table.coverPhotoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventPeg => $composableBuilder(
    column: $table.eventPeg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ScheduleType, String> get scheduleType =>
      $composableBuilder(
        column: $table.scheduleType,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
  get scheduleConfig => $composableBuilder(
    column: $table.scheduleConfig,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPhotoId => $composableBuilder(
    column: $table.coverPhotoId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<EventPeg, String> get eventPeg =>
      $composableBuilder(column: $table.eventPeg, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> membersRefs<T extends Object>(
    Expression<T> Function($$MembersTableAnnotationComposer a) f,
  ) {
    final $$MembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableAnnotationComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> placesRefs<T extends Object>(
    Expression<T> Function($$PlacesTableAnnotationComposer a) f,
  ) {
    final $$PlacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableAnnotationComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> capturesRefs<T extends Object>(
    Expression<T> Function($$CapturesTableAnnotationComposer a) f,
  ) {
    final $$CapturesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.captures,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CapturesTableAnnotationComposer(
            $db: $db,
            $table: $db.captures,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, $$ProjectsTableReferences),
          Project,
          PrefetchHooks Function({
            bool membersRefs,
            bool placesRefs,
            bool capturesRefs,
          })
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<ScheduleType> scheduleType = const Value.absent(),
                Value<Map<String, dynamic>> scheduleConfig =
                    const Value.absent(),
                Value<String?> coverPhotoId = const Value.absent(),
                Value<EventPeg> eventPeg = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                title: title,
                scheduleType: scheduleType,
                scheduleConfig: scheduleConfig,
                coverPhotoId: coverPhotoId,
                eventPeg: eventPeg,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required ScheduleType scheduleType,
                Value<Map<String, dynamic>> scheduleConfig =
                    const Value.absent(),
                Value<String?> coverPhotoId = const Value.absent(),
                Value<EventPeg> eventPeg = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                title: title,
                scheduleType: scheduleType,
                scheduleConfig: scheduleConfig,
                coverPhotoId: coverPhotoId,
                eventPeg: eventPeg,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                membersRefs = false,
                placesRefs = false,
                capturesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (membersRefs) db.members,
                    if (placesRefs) db.places,
                    if (capturesRefs) db.captures,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (membersRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Member
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._membersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).membersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (placesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Place
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._placesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).placesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (capturesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Capture
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._capturesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).capturesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
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

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, $$ProjectsTableReferences),
      Project,
      PrefetchHooks Function({
        bool membersRefs,
        bool placesRefs,
        bool capturesRefs,
      })
    >;
typedef $$MembersTableCreateCompanionBuilder =
    MembersCompanion Function({
      required String id,
      required String projectId,
      required String name,
      Value<String?> role,
      Value<int> rowid,
    });
typedef $$MembersTableUpdateCompanionBuilder =
    MembersCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> name,
      Value<String?> role,
      Value<int> rowid,
    });

final class $$MembersTableReferences
    extends BaseReferences<_$AppDatabase, $MembersTable, Member> {
  $$MembersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('members__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CaptureMembersTable, List<CaptureMember>>
  _captureMembersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.captureMembers,
    aliasName: 'members__id__capture_members__member_id',
  );

  $$CaptureMembersTableProcessedTableManager get captureMembersRefs {
    final manager = $$CaptureMembersTableTableManager(
      $_db,
      $_db.captureMembers,
    ).filter((f) => f.memberId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_captureMembersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MembersTableFilterComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> captureMembersRefs(
    Expression<bool> Function($$CaptureMembersTableFilterComposer f) f,
  ) {
    final $$CaptureMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.captureMembers,
      getReferencedColumn: (t) => t.memberId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureMembersTableFilterComposer(
            $db: $db,
            $table: $db.captureMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MembersTableOrderingComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> captureMembersRefs<T extends Object>(
    Expression<T> Function($$CaptureMembersTableAnnotationComposer a) f,
  ) {
    final $$CaptureMembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.captureMembers,
      getReferencedColumn: (t) => t.memberId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureMembersTableAnnotationComposer(
            $db: $db,
            $table: $db.captureMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MembersTable,
          Member,
          $$MembersTableFilterComposer,
          $$MembersTableOrderingComposer,
          $$MembersTableAnnotationComposer,
          $$MembersTableCreateCompanionBuilder,
          $$MembersTableUpdateCompanionBuilder,
          (Member, $$MembersTableReferences),
          Member,
          PrefetchHooks Function({bool projectId, bool captureMembersRefs})
        > {
  $$MembersTableTableManager(_$AppDatabase db, $MembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MembersCompanion(
                id: id,
                projectId: projectId,
                name: name,
                role: role,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String name,
                Value<String?> role = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MembersCompanion.insert(
                id: id,
                projectId: projectId,
                name: name,
                role: role,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MembersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({projectId = false, captureMembersRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (captureMembersRefs) db.captureMembers,
                  ],
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
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable: $$MembersTableReferences
                                        ._projectIdTable(db),
                                    referencedColumn: $$MembersTableReferences
                                        ._projectIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (captureMembersRefs)
                        await $_getPrefetchedData<
                          Member,
                          $MembersTable,
                          CaptureMember
                        >(
                          currentTable: table,
                          referencedTable: $$MembersTableReferences
                              ._captureMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MembersTableReferences(
                                db,
                                table,
                                p0,
                              ).captureMembersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.memberId == item.id,
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

typedef $$MembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MembersTable,
      Member,
      $$MembersTableFilterComposer,
      $$MembersTableOrderingComposer,
      $$MembersTableAnnotationComposer,
      $$MembersTableCreateCompanionBuilder,
      $$MembersTableUpdateCompanionBuilder,
      (Member, $$MembersTableReferences),
      Member,
      PrefetchHooks Function({bool projectId, bool captureMembersRefs})
    >;
typedef $$PlacesTableCreateCompanionBuilder =
    PlacesCompanion Function({
      required String id,
      required String projectId,
      required String label,
      required double latitude,
      required double longitude,
      Value<int> radiusM,
      Value<int> captureCount,
      Value<bool> geofenceEnabled,
      Value<int> rowid,
    });
typedef $$PlacesTableUpdateCompanionBuilder =
    PlacesCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> label,
      Value<double> latitude,
      Value<double> longitude,
      Value<int> radiusM,
      Value<int> captureCount,
      Value<bool> geofenceEnabled,
      Value<int> rowid,
    });

final class $$PlacesTableReferences
    extends BaseReferences<_$AppDatabase, $PlacesTable, Place> {
  $$PlacesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('places__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CapturesTable, List<Capture>> _capturesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.captures,
    aliasName: 'places__id__captures__place_id',
  );

  $$CapturesTableProcessedTableManager get capturesRefs {
    final manager = $$CapturesTableTableManager(
      $_db,
      $_db.captures,
    ).filter((f) => f.placeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_capturesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlacesTableFilterComposer
    extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableFilterComposer({
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

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
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

  ColumnFilters<int> get radiusM => $composableBuilder(
    column: $table.radiusM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get captureCount => $composableBuilder(
    column: $table.captureCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get geofenceEnabled => $composableBuilder(
    column: $table.geofenceEnabled,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> capturesRefs(
    Expression<bool> Function($$CapturesTableFilterComposer f) f,
  ) {
    final $$CapturesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.captures,
      getReferencedColumn: (t) => t.placeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CapturesTableFilterComposer(
            $db: $db,
            $table: $db.captures,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlacesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableOrderingComposer({
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

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
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

  ColumnOrderings<int> get radiusM => $composableBuilder(
    column: $table.radiusM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get captureCount => $composableBuilder(
    column: $table.captureCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get geofenceEnabled => $composableBuilder(
    column: $table.geofenceEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlacesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get radiusM =>
      $composableBuilder(column: $table.radiusM, builder: (column) => column);

  GeneratedColumn<int> get captureCount => $composableBuilder(
    column: $table.captureCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get geofenceEnabled => $composableBuilder(
    column: $table.geofenceEnabled,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> capturesRefs<T extends Object>(
    Expression<T> Function($$CapturesTableAnnotationComposer a) f,
  ) {
    final $$CapturesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.captures,
      getReferencedColumn: (t) => t.placeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CapturesTableAnnotationComposer(
            $db: $db,
            $table: $db.captures,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlacesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlacesTable,
          Place,
          $$PlacesTableFilterComposer,
          $$PlacesTableOrderingComposer,
          $$PlacesTableAnnotationComposer,
          $$PlacesTableCreateCompanionBuilder,
          $$PlacesTableUpdateCompanionBuilder,
          (Place, $$PlacesTableReferences),
          Place,
          PrefetchHooks Function({bool projectId, bool capturesRefs})
        > {
  $$PlacesTableTableManager(_$AppDatabase db, $PlacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<int> radiusM = const Value.absent(),
                Value<int> captureCount = const Value.absent(),
                Value<bool> geofenceEnabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlacesCompanion(
                id: id,
                projectId: projectId,
                label: label,
                latitude: latitude,
                longitude: longitude,
                radiusM: radiusM,
                captureCount: captureCount,
                geofenceEnabled: geofenceEnabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String label,
                required double latitude,
                required double longitude,
                Value<int> radiusM = const Value.absent(),
                Value<int> captureCount = const Value.absent(),
                Value<bool> geofenceEnabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlacesCompanion.insert(
                id: id,
                projectId: projectId,
                label: label,
                latitude: latitude,
                longitude: longitude,
                radiusM: radiusM,
                captureCount: captureCount,
                geofenceEnabled: geofenceEnabled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PlacesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false, capturesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (capturesRefs) db.captures],
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
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$PlacesTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$PlacesTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (capturesRefs)
                    await $_getPrefetchedData<Place, $PlacesTable, Capture>(
                      currentTable: table,
                      referencedTable: $$PlacesTableReferences
                          ._capturesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlacesTableReferences(db, table, p0).capturesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.placeId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlacesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlacesTable,
      Place,
      $$PlacesTableFilterComposer,
      $$PlacesTableOrderingComposer,
      $$PlacesTableAnnotationComposer,
      $$PlacesTableCreateCompanionBuilder,
      $$PlacesTableUpdateCompanionBuilder,
      (Place, $$PlacesTableReferences),
      Place,
      PrefetchHooks Function({bool projectId, bool capturesRefs})
    >;
typedef $$CapturesTableCreateCompanionBuilder =
    CapturesCompanion Function({
      required String id,
      required String projectId,
      required String filePath,
      required String thumbPath,
      required DateTime capturedAt,
      required String periodLabel,
      Value<Map<String, dynamic>?> alignmentMeta,
      Value<String?> note,
      Value<String?> placeId,
      Value<BackupState> backupState,
      Value<String?> decoratedPath,
      Value<int?> sortIndex,
      Value<int> rowid,
    });
typedef $$CapturesTableUpdateCompanionBuilder =
    CapturesCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> filePath,
      Value<String> thumbPath,
      Value<DateTime> capturedAt,
      Value<String> periodLabel,
      Value<Map<String, dynamic>?> alignmentMeta,
      Value<String?> note,
      Value<String?> placeId,
      Value<BackupState> backupState,
      Value<String?> decoratedPath,
      Value<int?> sortIndex,
      Value<int> rowid,
    });

final class $$CapturesTableReferences
    extends BaseReferences<_$AppDatabase, $CapturesTable, Capture> {
  $$CapturesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('captures__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlacesTable _placeIdTable(_$AppDatabase db) =>
      db.places.createAlias('captures__place_id__places__id');

  $$PlacesTableProcessedTableManager? get placeId {
    final $_column = $_itemColumn<String>('place_id');
    if ($_column == null) return null;
    final manager = $$PlacesTableTableManager(
      $_db,
      $_db.places,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_placeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CaptureMembersTable, List<CaptureMember>>
  _captureMembersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.captureMembers,
    aliasName: 'captures__id__capture_members__capture_id',
  );

  $$CaptureMembersTableProcessedTableManager get captureMembersRefs {
    final manager = $$CaptureMembersTableTableManager(
      $_db,
      $_db.captureMembers,
    ).filter((f) => f.captureId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_captureMembersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CapturesTableFilterComposer
    extends Composer<_$AppDatabase, $CapturesTable> {
  $$CapturesTableFilterComposer({
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

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbPath => $composableBuilder(
    column: $table.thumbPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodLabel => $composableBuilder(
    column: $table.periodLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    Map<String, dynamic>?,
    Map<String, dynamic>,
    String
  >
  get alignmentMeta => $composableBuilder(
    column: $table.alignmentMeta,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BackupState, BackupState, String>
  get backupState => $composableBuilder(
    column: $table.backupState,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get decoratedPath => $composableBuilder(
    column: $table.decoratedPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlacesTableFilterComposer get placeId {
    final $$PlacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeId,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableFilterComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> captureMembersRefs(
    Expression<bool> Function($$CaptureMembersTableFilterComposer f) f,
  ) {
    final $$CaptureMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.captureMembers,
      getReferencedColumn: (t) => t.captureId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureMembersTableFilterComposer(
            $db: $db,
            $table: $db.captureMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CapturesTableOrderingComposer
    extends Composer<_$AppDatabase, $CapturesTable> {
  $$CapturesTableOrderingComposer({
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

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbPath => $composableBuilder(
    column: $table.thumbPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodLabel => $composableBuilder(
    column: $table.periodLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alignmentMeta => $composableBuilder(
    column: $table.alignmentMeta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backupState => $composableBuilder(
    column: $table.backupState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decoratedPath => $composableBuilder(
    column: $table.decoratedPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlacesTableOrderingComposer get placeId {
    final $$PlacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeId,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableOrderingComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CapturesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CapturesTable> {
  $$CapturesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get thumbPath =>
      $composableBuilder(column: $table.thumbPath, builder: (column) => column);

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get periodLabel => $composableBuilder(
    column: $table.periodLabel,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Map<String, dynamic>?, String>
  get alignmentMeta => $composableBuilder(
    column: $table.alignmentMeta,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BackupState, String> get backupState =>
      $composableBuilder(
        column: $table.backupState,
        builder: (column) => column,
      );

  GeneratedColumn<String> get decoratedPath => $composableBuilder(
    column: $table.decoratedPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlacesTableAnnotationComposer get placeId {
    final $$PlacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeId,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableAnnotationComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> captureMembersRefs<T extends Object>(
    Expression<T> Function($$CaptureMembersTableAnnotationComposer a) f,
  ) {
    final $$CaptureMembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.captureMembers,
      getReferencedColumn: (t) => t.captureId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureMembersTableAnnotationComposer(
            $db: $db,
            $table: $db.captureMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CapturesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CapturesTable,
          Capture,
          $$CapturesTableFilterComposer,
          $$CapturesTableOrderingComposer,
          $$CapturesTableAnnotationComposer,
          $$CapturesTableCreateCompanionBuilder,
          $$CapturesTableUpdateCompanionBuilder,
          (Capture, $$CapturesTableReferences),
          Capture,
          PrefetchHooks Function({
            bool projectId,
            bool placeId,
            bool captureMembersRefs,
          })
        > {
  $$CapturesTableTableManager(_$AppDatabase db, $CapturesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CapturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CapturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CapturesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> thumbPath = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<String> periodLabel = const Value.absent(),
                Value<Map<String, dynamic>?> alignmentMeta =
                    const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> placeId = const Value.absent(),
                Value<BackupState> backupState = const Value.absent(),
                Value<String?> decoratedPath = const Value.absent(),
                Value<int?> sortIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CapturesCompanion(
                id: id,
                projectId: projectId,
                filePath: filePath,
                thumbPath: thumbPath,
                capturedAt: capturedAt,
                periodLabel: periodLabel,
                alignmentMeta: alignmentMeta,
                note: note,
                placeId: placeId,
                backupState: backupState,
                decoratedPath: decoratedPath,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String filePath,
                required String thumbPath,
                required DateTime capturedAt,
                required String periodLabel,
                Value<Map<String, dynamic>?> alignmentMeta =
                    const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> placeId = const Value.absent(),
                Value<BackupState> backupState = const Value.absent(),
                Value<String?> decoratedPath = const Value.absent(),
                Value<int?> sortIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CapturesCompanion.insert(
                id: id,
                projectId: projectId,
                filePath: filePath,
                thumbPath: thumbPath,
                capturedAt: capturedAt,
                periodLabel: periodLabel,
                alignmentMeta: alignmentMeta,
                note: note,
                placeId: placeId,
                backupState: backupState,
                decoratedPath: decoratedPath,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CapturesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                placeId = false,
                captureMembersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (captureMembersRefs) db.captureMembers,
                  ],
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
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable: $$CapturesTableReferences
                                        ._projectIdTable(db),
                                    referencedColumn: $$CapturesTableReferences
                                        ._projectIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (placeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.placeId,
                                    referencedTable: $$CapturesTableReferences
                                        ._placeIdTable(db),
                                    referencedColumn: $$CapturesTableReferences
                                        ._placeIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (captureMembersRefs)
                        await $_getPrefetchedData<
                          Capture,
                          $CapturesTable,
                          CaptureMember
                        >(
                          currentTable: table,
                          referencedTable: $$CapturesTableReferences
                              ._captureMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CapturesTableReferences(
                                db,
                                table,
                                p0,
                              ).captureMembersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.captureId == item.id,
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

typedef $$CapturesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CapturesTable,
      Capture,
      $$CapturesTableFilterComposer,
      $$CapturesTableOrderingComposer,
      $$CapturesTableAnnotationComposer,
      $$CapturesTableCreateCompanionBuilder,
      $$CapturesTableUpdateCompanionBuilder,
      (Capture, $$CapturesTableReferences),
      Capture,
      PrefetchHooks Function({
        bool projectId,
        bool placeId,
        bool captureMembersRefs,
      })
    >;
typedef $$CaptureMembersTableCreateCompanionBuilder =
    CaptureMembersCompanion Function({
      required String captureId,
      required String memberId,
      Value<int> rowid,
    });
typedef $$CaptureMembersTableUpdateCompanionBuilder =
    CaptureMembersCompanion Function({
      Value<String> captureId,
      Value<String> memberId,
      Value<int> rowid,
    });

final class $$CaptureMembersTableReferences
    extends BaseReferences<_$AppDatabase, $CaptureMembersTable, CaptureMember> {
  $$CaptureMembersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CapturesTable _captureIdTable(_$AppDatabase db) =>
      db.captures.createAlias('capture_members__capture_id__captures__id');

  $$CapturesTableProcessedTableManager get captureId {
    final $_column = $_itemColumn<String>('capture_id')!;

    final manager = $$CapturesTableTableManager(
      $_db,
      $_db.captures,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_captureIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MembersTable _memberIdTable(_$AppDatabase db) =>
      db.members.createAlias('capture_members__member_id__members__id');

  $$MembersTableProcessedTableManager get memberId {
    final $_column = $_itemColumn<String>('member_id')!;

    final manager = $$MembersTableTableManager(
      $_db,
      $_db.members,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memberIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CaptureMembersTableFilterComposer
    extends Composer<_$AppDatabase, $CaptureMembersTable> {
  $$CaptureMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CapturesTableFilterComposer get captureId {
    final $$CapturesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureId,
      referencedTable: $db.captures,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CapturesTableFilterComposer(
            $db: $db,
            $table: $db.captures,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MembersTableFilterComposer get memberId {
    final $$MembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memberId,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableFilterComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CaptureMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $CaptureMembersTable> {
  $$CaptureMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CapturesTableOrderingComposer get captureId {
    final $$CapturesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureId,
      referencedTable: $db.captures,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CapturesTableOrderingComposer(
            $db: $db,
            $table: $db.captures,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MembersTableOrderingComposer get memberId {
    final $$MembersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memberId,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableOrderingComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CaptureMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CaptureMembersTable> {
  $$CaptureMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CapturesTableAnnotationComposer get captureId {
    final $$CapturesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureId,
      referencedTable: $db.captures,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CapturesTableAnnotationComposer(
            $db: $db,
            $table: $db.captures,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MembersTableAnnotationComposer get memberId {
    final $$MembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memberId,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableAnnotationComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CaptureMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CaptureMembersTable,
          CaptureMember,
          $$CaptureMembersTableFilterComposer,
          $$CaptureMembersTableOrderingComposer,
          $$CaptureMembersTableAnnotationComposer,
          $$CaptureMembersTableCreateCompanionBuilder,
          $$CaptureMembersTableUpdateCompanionBuilder,
          (CaptureMember, $$CaptureMembersTableReferences),
          CaptureMember,
          PrefetchHooks Function({bool captureId, bool memberId})
        > {
  $$CaptureMembersTableTableManager(
    _$AppDatabase db,
    $CaptureMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaptureMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CaptureMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CaptureMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> captureId = const Value.absent(),
                Value<String> memberId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaptureMembersCompanion(
                captureId: captureId,
                memberId: memberId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String captureId,
                required String memberId,
                Value<int> rowid = const Value.absent(),
              }) => CaptureMembersCompanion.insert(
                captureId: captureId,
                memberId: memberId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CaptureMembersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({captureId = false, memberId = false}) {
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
                    if (captureId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.captureId,
                                referencedTable: $$CaptureMembersTableReferences
                                    ._captureIdTable(db),
                                referencedColumn:
                                    $$CaptureMembersTableReferences
                                        ._captureIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (memberId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memberId,
                                referencedTable: $$CaptureMembersTableReferences
                                    ._memberIdTable(db),
                                referencedColumn:
                                    $$CaptureMembersTableReferences
                                        ._memberIdTable(db)
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

typedef $$CaptureMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CaptureMembersTable,
      CaptureMember,
      $$CaptureMembersTableFilterComposer,
      $$CaptureMembersTableOrderingComposer,
      $$CaptureMembersTableAnnotationComposer,
      $$CaptureMembersTableCreateCompanionBuilder,
      $$CaptureMembersTableUpdateCompanionBuilder,
      (CaptureMember, $$CaptureMembersTableReferences),
      CaptureMember,
      PrefetchHooks Function({bool captureId, bool memberId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$MembersTableTableManager get members =>
      $$MembersTableTableManager(_db, _db.members);
  $$PlacesTableTableManager get places =>
      $$PlacesTableTableManager(_db, _db.places);
  $$CapturesTableTableManager get captures =>
      $$CapturesTableTableManager(_db, _db.captures);
  $$CaptureMembersTableTableManager get captureMembers =>
      $$CaptureMembersTableTableManager(_db, _db.captureMembers);
}
