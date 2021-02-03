//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

#define DD_LEGACY_MACROS 0

#import <CocoaLumberjack/CocoaLumberjack.h>

#define LOG_FLAG_NOTICE (1 << 5)
#define DDLogNotice(frmt, ...)  LOG_MAYBE(YES, ddLogLevel, LOG_FLAG_NOTICE,  0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)

static uint const DDLogFlagNotice = LOG_FLAG_NOTICE;
static uint const DDLogLevelNotice = DDLogFlagError | DDLogFlagWarning | DDLogFlagNotice;
