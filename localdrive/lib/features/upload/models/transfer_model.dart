import '../../../core/enums/transfer_status.dart';

/// One queued transfer.
///
/// The queue is the source of truth, not memory: an item is written to durable
/// storage the moment it is enqueued, before any network call starts, so if
/// the app is killed a second later the intent survives and picks back up on
/// next launch.
class TransferModel {
  const TransferModel({
    required this.id,
    required this.kind,
    required this.name,
    required this.status,
    this.localPath = '',
    this.parentId = '',
    this.nodeId = '',
    this.mimeType = '',
    this.totalBytes = 0,
    this.transferredBytes = 0,
    this.uploadUrl = '',
    this.attempts = 0,
    this.nextAttemptAt = 0,
    this.failureReason = FailureReason.unknown,
    this.failureMessage = '',
    this.sourceUrl = '',
    this.destinationPath = '',
    this.savedTo = '',
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  final String id;
  final TransferKind kind;
  final String name;
  final TransferStatus status;
  final String localPath;
  final String parentId;

  /// set when this upload replaces an existing file with a new version
  final String nodeId;
  final String mimeType;
  final int totalBytes;
  final int transferredBytes;

  /// the tus upload url, which makes a resume continue from the last
  /// acknowledged byte rather than from zero
  final String uploadUrl;
  final int attempts;
  final int nextAttemptAt;
  final FailureReason failureReason;
  final String failureMessage;

  /// an absolute URL to pull from instead of the node download endpoint. Set
  /// only for a public link, which has a token and no session behind it
  final String sourceUrl;

  /// an exact path to write to instead of this platform's downloads folder.
  /// Set only for offline availability, which keeps its copies inside the
  /// app's own directory so clearing them is one operation and not a hunt
  final String destinationPath;

  /// where a finished download actually landed, so the completion notice can
  /// name a real location rather than say "done" and leave you looking for it
  final String savedTo;
  final int createdAt;
  final int updatedAt;

  double get progress =>
      totalBytes <= 0 ? 0 : (transferredBytes / totalBytes).clamp(0.0, 1.0);

  bool get isActive => status.isActive;
  bool get needsAttention => status.needsAttention;

  /// only a transient failure is worth retrying forever; an expired session, a
  /// permission error, or a full quota surfaces immediately instead
  bool get canRetry => status == TransferStatus.failed;

  TransferModel copyWith({
    TransferStatus? status,
    int? totalBytes,
    int? transferredBytes,
    String? uploadUrl,
    String? nodeId,
    int? attempts,
    int? nextAttemptAt,
    FailureReason? failureReason,
    String? failureMessage,
    String? savedTo,
    int? updatedAt,
  }) =>
      TransferModel(
        id: id,
        kind: kind,
        name: name,
        status: status ?? this.status,
        localPath: localPath,
        parentId: parentId,
        nodeId: nodeId ?? this.nodeId,
        mimeType: mimeType,
        totalBytes: totalBytes ?? this.totalBytes,
        transferredBytes: transferredBytes ?? this.transferredBytes,
        uploadUrl: uploadUrl ?? this.uploadUrl,
        attempts: attempts ?? this.attempts,
        nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
        failureReason: failureReason ?? this.failureReason,
        failureMessage: failureMessage ?? this.failureMessage,
        sourceUrl: sourceUrl,
        destinationPath: destinationPath,
        savedTo: savedTo ?? this.savedTo,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'name': name,
        'status': status.name,
        'local_path': localPath,
        'parent_id': parentId,
        'node_id': nodeId,
        'mime_type': mimeType,
        'total_bytes': totalBytes,
        'transferred_bytes': transferredBytes,
        'upload_url': uploadUrl,
        'attempts': attempts,
        'next_attempt_at': nextAttemptAt,
        'failure_reason': failureReason.name,
        'failure_message': failureMessage,
        'source_url': sourceUrl,
        'destination_path': destinationPath,
        'saved_to': savedTo,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory TransferModel.fromJson(Map<String, dynamic> json) => TransferModel(
        id: json['id'] as String? ?? '',
        kind: TransferKind.fromName(json['kind'] as String? ?? 'upload'),
        name: json['name'] as String? ?? '',
        status: TransferStatus.fromName(json['status'] as String? ?? 'queued'),
        localPath: json['local_path'] as String? ?? '',
        parentId: json['parent_id'] as String? ?? '',
        nodeId: json['node_id'] as String? ?? '',
        mimeType: json['mime_type'] as String? ?? '',
        totalBytes: json['total_bytes'] as int? ?? 0,
        transferredBytes: json['transferred_bytes'] as int? ?? 0,
        uploadUrl: json['upload_url'] as String? ?? '',
        attempts: json['attempts'] as int? ?? 0,
        nextAttemptAt: json['next_attempt_at'] as int? ?? 0,
        failureReason:
            FailureReason.fromName(json['failure_reason'] as String?),
        failureMessage: json['failure_message'] as String? ?? '',
        sourceUrl: json['source_url'] as String? ?? '',
        destinationPath: json['destination_path'] as String? ?? '',
        savedTo: json['saved_to'] as String? ?? '',
        createdAt: json['created_at'] as int? ?? 0,
        updatedAt: json['updated_at'] as int? ?? 0,
      );
}

/// What the uploads tray shows at a glance.
class TransferSummary {
  const TransferSummary({
    required this.total,
    required this.completed,
    required this.active,
    required this.failed,
    required this.paused,
  });

  final int total;
  final int completed;
  final int active;
  final int failed;
  final bool paused;

  bool get isEmpty => total == 0;
  bool get isBusy => active > 0;
  bool get needsAttention => failed > 0;

  double get progress => total == 0 ? 0 : completed / total;

  static TransferSummary of(Iterable<TransferModel> transfers) {
    var total = 0;
    var completed = 0;
    var active = 0;
    var failed = 0;
    var paused = false;
    for (final transfer in transfers) {
      total++;
      switch (transfer.status) {
        case TransferStatus.completed:
          completed++;
        case TransferStatus.inProgress:
        case TransferStatus.retrying:
          active++;
        case TransferStatus.failed:
          failed++;
        case TransferStatus.paused:
          paused = true;
        case TransferStatus.queued:
          break;
      }
    }
    return TransferSummary(
      total: total,
      completed: completed,
      active: active,
      failed: failed,
      paused: paused,
    );
  }
}
