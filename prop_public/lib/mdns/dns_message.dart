//INFO: This is a stub - contact me if you need the full implementation.
//
// The full implementation encodes and decodes mDNS messages. This stub keeps
// the surface the app uses: a query encodes to nothing and nothing decodes, so
// a lookup through it simply finds no answer.

import 'dart:typed_data';

abstract final class DnsType {
  static const int a = 1;
  static const int ptr = 12;
  static const int txt = 16;
  static const int aaaa = 28;
  static const int srv = 33;
  static const int any = 255;
}

abstract final class DnsClass {
  static const int internet = 1;
}

class DnsName {
  final List<String> labels;

  const DnsName(this.labels);

  factory DnsName.fromString(String dotted) => DnsName(dotted.split('.').where((l) => l.isNotEmpty).toList());

  String get dotted => labels.join('.');

  bool matches(DnsName other) {
    if (labels.length != other.labels.length) return false;
    for (var i = 0; i < labels.length; i++) {
      if (labels[i].toLowerCase() != other.labels[i].toLowerCase()) return false;
    }
    return true;
  }

  @override
  String toString() => dotted;
}

class DnsQuestion {
  final DnsName name;
  final int type;
  final int dnsClass;
  final bool wantsUnicastResponse;

  DnsQuestion({
    required this.name,
    required this.type,
    this.dnsClass = DnsClass.internet,
    this.wantsUnicastResponse = false,
  });
}

sealed class DnsRecord {
  final DnsName name;
  final int type;
  final int dnsClass;
  final bool cacheFlush;
  final int ttl;

  DnsRecord({
    required this.name,
    required this.type,
    this.dnsClass = DnsClass.internet,
    this.cacheFlush = false,
    required this.ttl,
  });
}

class ARecord extends DnsRecord {
  final String address;

  ARecord({
    required super.name,
    required this.address,
    super.dnsClass,
    super.cacheFlush,
    required super.ttl,
  }) : super(type: DnsType.a);
}

class DnsMessage {
  final int id;
  final bool isResponse;
  final bool isAuthoritative;
  final List<DnsQuestion> questions;
  final List<DnsRecord> answers;
  final List<DnsRecord> authority;
  final List<DnsRecord> additionals;

  DnsMessage({
    this.id = 0,
    this.isResponse = false,
    this.isAuthoritative = false,
    this.questions = const [],
    this.answers = const [],
    this.authority = const [],
    this.additionals = const [],
  });

  Uint8List encode() => Uint8List(0);

  static DnsMessage? decode(Uint8List data) => null;
}
