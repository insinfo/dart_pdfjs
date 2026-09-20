// Copyright 2026
// SPDX-License-Identifier: Apache-2.0

import 'viewer_storage.dart';

ViewerStorage createLocalViewerStorage() => MemoryViewerStorage();

ViewerStorage createSessionViewerStorage() => MemoryViewerStorage();
