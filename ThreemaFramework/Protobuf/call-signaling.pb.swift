//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

/// Root signaling message
struct Callsignaling_Envelope {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// Random amount of padding (0-255 bytes), ignored by the receiver
  var padding: Data = SwiftProtobuf.Internal.emptyData

  var content: Callsignaling_Envelope.OneOf_Content? = nil

  var videoQualityProfile: Callsignaling_VideoQualityProfile {
    get {
      if case .videoQualityProfile(let v)? = content {return v}
      return Callsignaling_VideoQualityProfile()
    }
    set {content = .videoQualityProfile(newValue)}
  }

  var captureStateChange: Callsignaling_CaptureState {
    get {
      if case .captureStateChange(let v)? = content {return v}
      return Callsignaling_CaptureState()
    }
    set {content = .captureStateChange(newValue)}
  }

  var unknownFields = SwiftProtobuf.UnknownStorage()

  enum OneOf_Content: Equatable {
    case videoQualityProfile(Callsignaling_VideoQualityProfile)
    case captureStateChange(Callsignaling_CaptureState)

  #if !swift(>=4.1)
    static func ==(lhs: Callsignaling_Envelope.OneOf_Content, rhs: Callsignaling_Envelope.OneOf_Content) -> Bool {
      switch (lhs, rhs) {
      case (.videoQualityProfile(let l), .videoQualityProfile(let r)): return l == r
      case (.captureStateChange(let l), .captureStateChange(let r)): return l == r
      default: return false
      }
    }
  #endif
  }

  init() {}
}

/// Generic 2D resolution
struct Callsignaling_Resolution {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var width: UInt32 = 0

  var height: UInt32 = 0

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

/// The app switched to a new video quality profile
///
/// In order to be forwards-compatible, the raw configuration of the profile
/// (bitrate, resolution, etc) should also be included in this message. This
/// way, if an unknown enum value is received, the receiver can simply use the
/// raw values instead.
struct Callsignaling_VideoQualityProfile {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var profile: Callsignaling_VideoQualityProfile.QualityProfile = .max

  /// The max bitrate in kbps
  var maxBitrateKbps: UInt32 = 0

  /// The max resolution (in landscape orientation)
  var maxResolution: Callsignaling_Resolution {
    get {return _maxResolution ?? Callsignaling_Resolution()}
    set {_maxResolution = newValue}
  }
  /// Returns true if `maxResolution` has been explicitly set.
  var hasMaxResolution: Bool {return self._maxResolution != nil}
  /// Clears the value of `maxResolution`. Subsequent reads from it will return its default value.
  mutating func clearMaxResolution() {self._maxResolution = nil}

  /// The max framerate
  var maxFps: UInt32 = 0

  var unknownFields = SwiftProtobuf.UnknownStorage()

  /// The quality profile
  enum QualityProfile: SwiftProtobuf.Enum {
    typealias RawValue = Int

    /// Very high quality, used only when explicitly selected by the user
    case max // = 0

    /// High quality, used by default in non-metered networks
    case high // = 1

    /// Low quality, optimize for bandwidth, used by default in metered networks
    case low // = 2
    case UNRECOGNIZED(Int)

    init() {
      self = .max
    }

    init?(rawValue: Int) {
      switch rawValue {
      case 0: self = .max
      case 1: self = .high
      case 2: self = .low
      default: self = .UNRECOGNIZED(rawValue)
      }
    }

    var rawValue: Int {
      switch self {
      case .max: return 0
      case .high: return 1
      case .low: return 2
      case .UNRECOGNIZED(let i): return i
      }
    }

  }

  init() {}

  fileprivate var _maxResolution: Callsignaling_Resolution? = nil
}

#if swift(>=4.2)

extension Callsignaling_VideoQualityProfile.QualityProfile: CaseIterable {
  // The compiler won't synthesize support with the UNRECOGNIZED case.
  static var allCases: [Callsignaling_VideoQualityProfile.QualityProfile] = [
    .max,
    .high,
    .low,
  ]
}

#endif  // swift(>=4.2)

/// Signal changes in the capturing state (e.g. video camera enabled or disabled)
struct Callsignaling_CaptureState {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var state: Callsignaling_CaptureState.Mode = .off

  var device: Callsignaling_CaptureState.CaptureDevice = .camera

  var unknownFields = SwiftProtobuf.UnknownStorage()

  /// The capture state of a capturing device
  enum Mode: SwiftProtobuf.Enum {
    typealias RawValue = Int

    /// Off, not sending any data
    case off // = 0

    /// On, sending data
    case on // = 1
    case UNRECOGNIZED(Int)

    init() {
      self = .off
    }

    init?(rawValue: Int) {
      switch rawValue {
      case 0: self = .off
      case 1: self = .on
      default: self = .UNRECOGNIZED(rawValue)
      }
    }

    var rawValue: Int {
      switch self {
      case .off: return 0
      case .on: return 1
      case .UNRECOGNIZED(let i): return i
      }
    }

  }

  /// The capture device type
  enum CaptureDevice: SwiftProtobuf.Enum {
    typealias RawValue = Int

    /// Capturing from a camera
    case camera // = 0

    /// Capturing from screen sharing
    case screenSharing // = 1

    /// Capturing from a microphone
    case microphone // = 2
    case UNRECOGNIZED(Int)

    init() {
      self = .camera
    }

    init?(rawValue: Int) {
      switch rawValue {
      case 0: self = .camera
      case 1: self = .screenSharing
      case 2: self = .microphone
      default: self = .UNRECOGNIZED(rawValue)
      }
    }

    var rawValue: Int {
      switch self {
      case .camera: return 0
      case .screenSharing: return 1
      case .microphone: return 2
      case .UNRECOGNIZED(let i): return i
      }
    }

  }

  init() {}
}

#if swift(>=4.2)

extension Callsignaling_CaptureState.Mode: CaseIterable {
  // The compiler won't synthesize support with the UNRECOGNIZED case.
  static var allCases: [Callsignaling_CaptureState.Mode] = [
    .off,
    .on,
  ]
}

extension Callsignaling_CaptureState.CaptureDevice: CaseIterable {
  // The compiler won't synthesize support with the UNRECOGNIZED case.
  static var allCases: [Callsignaling_CaptureState.CaptureDevice] = [
    .camera,
    .screenSharing,
    .microphone,
  ]
}

#endif  // swift(>=4.2)

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "callsignaling"

extension Callsignaling_Envelope: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".Envelope"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "padding"),
    2: .standard(proto: "video_quality_profile"),
    3: .standard(proto: "capture_state_change"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      switch fieldNumber {
      case 1: try decoder.decodeSingularBytesField(value: &self.padding)
      case 2:
        var v: Callsignaling_VideoQualityProfile?
        if let current = self.content {
          try decoder.handleConflictingOneOf()
          if case .videoQualityProfile(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {self.content = .videoQualityProfile(v)}
      case 3:
        var v: Callsignaling_CaptureState?
        if let current = self.content {
          try decoder.handleConflictingOneOf()
          if case .captureStateChange(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {self.content = .captureStateChange(v)}
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.padding.isEmpty {
      try visitor.visitSingularBytesField(value: self.padding, fieldNumber: 1)
    }
    switch self.content {
    case .videoQualityProfile(let v)?:
      try visitor.visitSingularMessageField(value: v, fieldNumber: 2)
    case .captureStateChange(let v)?:
      try visitor.visitSingularMessageField(value: v, fieldNumber: 3)
    case nil: break
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Callsignaling_Envelope, rhs: Callsignaling_Envelope) -> Bool {
    if lhs.padding != rhs.padding {return false}
    if lhs.content != rhs.content {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Callsignaling_Resolution: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".Resolution"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "width"),
    2: .same(proto: "height"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      switch fieldNumber {
      case 1: try decoder.decodeSingularUInt32Field(value: &self.width)
      case 2: try decoder.decodeSingularUInt32Field(value: &self.height)
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.width != 0 {
      try visitor.visitSingularUInt32Field(value: self.width, fieldNumber: 1)
    }
    if self.height != 0 {
      try visitor.visitSingularUInt32Field(value: self.height, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Callsignaling_Resolution, rhs: Callsignaling_Resolution) -> Bool {
    if lhs.width != rhs.width {return false}
    if lhs.height != rhs.height {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Callsignaling_VideoQualityProfile: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".VideoQualityProfile"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "profile"),
    2: .standard(proto: "max_bitrate_kbps"),
    3: .standard(proto: "max_resolution"),
    4: .standard(proto: "max_fps"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      switch fieldNumber {
      case 1: try decoder.decodeSingularEnumField(value: &self.profile)
      case 2: try decoder.decodeSingularUInt32Field(value: &self.maxBitrateKbps)
      case 3: try decoder.decodeSingularMessageField(value: &self._maxResolution)
      case 4: try decoder.decodeSingularUInt32Field(value: &self.maxFps)
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.profile != .max {
      try visitor.visitSingularEnumField(value: self.profile, fieldNumber: 1)
    }
    if self.maxBitrateKbps != 0 {
      try visitor.visitSingularUInt32Field(value: self.maxBitrateKbps, fieldNumber: 2)
    }
    if let v = self._maxResolution {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 3)
    }
    if self.maxFps != 0 {
      try visitor.visitSingularUInt32Field(value: self.maxFps, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Callsignaling_VideoQualityProfile, rhs: Callsignaling_VideoQualityProfile) -> Bool {
    if lhs.profile != rhs.profile {return false}
    if lhs.maxBitrateKbps != rhs.maxBitrateKbps {return false}
    if lhs._maxResolution != rhs._maxResolution {return false}
    if lhs.maxFps != rhs.maxFps {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Callsignaling_VideoQualityProfile.QualityProfile: SwiftProtobuf._ProtoNameProviding {
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "MAX"),
    1: .same(proto: "HIGH"),
    2: .same(proto: "LOW"),
  ]
}

extension Callsignaling_CaptureState: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".CaptureState"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "state"),
    2: .same(proto: "device"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      switch fieldNumber {
      case 1: try decoder.decodeSingularEnumField(value: &self.state)
      case 2: try decoder.decodeSingularEnumField(value: &self.device)
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.state != .off {
      try visitor.visitSingularEnumField(value: self.state, fieldNumber: 1)
    }
    if self.device != .camera {
      try visitor.visitSingularEnumField(value: self.device, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Callsignaling_CaptureState, rhs: Callsignaling_CaptureState) -> Bool {
    if lhs.state != rhs.state {return false}
    if lhs.device != rhs.device {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Callsignaling_CaptureState.Mode: SwiftProtobuf._ProtoNameProviding {
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "OFF"),
    1: .same(proto: "ON"),
  ]
}

extension Callsignaling_CaptureState.CaptureDevice: SwiftProtobuf._ProtoNameProviding {
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "CAMERA"),
    1: .same(proto: "SCREEN_SHARING"),
    2: .same(proto: "MICROPHONE"),
  ]
}