;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: PREPARE-FM-PLUGIN-TOOLS; Base: 10 -*-

;;; Copyright (c) 2022, Chun Tian (binghe).  All rights reserved.

;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions
;;; are met:

;;;   * Redistributions of source code must retain the above copyright
;;;     notice, this list of conditions and the following disclaimer.

;;;   * Redistributions in binary form must reproduce the above
;;;     copyright notice, this list of conditions and the following
;;;     disclaimer in the documentation and/or other materials
;;;     provided with the distribution.

;;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR 'AS IS' AND ANY EXPRESSED
;;; OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
;;; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
;;; GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
;;; WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

(in-package :prepare-pdf-plugin-tools)

(defparameter *header-file-names*
  '("ASNumTypes"   ; Basic integer types.
    "CoreExpT"     ; Types, macros, structures, etc. required to use the Core HFT
    "ASExpT"       ; Types, macros, structures, etc. required to use the AcroSupport HFT
    "CorProcs"     ; Catalog of the "core" exported functions
                   ; (this table is handed off to the plug-in at initialization time)
    "CorCalls"
    "ASProcs"      ; Catalog of functions exported by AcroSupport
    "ASCalls"
    "PIVersn"      ; Contains handshaking versioning types and data

    "ASExtraExpT"  ; Types, macros, structures, etc. required to use the ASExtra HFT
    "ASExtraProcs" ; Catalog of functions exported by the ASExtra HFT
    "ASExtraCalls"

    "PDBasicExpT"  ; Types required to use the PDModel HFT (ONLY handles to exported types)
    "PDExpT"       ; Types, macros, structures, etc. required to use the PDModel HFT
    "AVExpT"       ; Types, macros, structures, etc. required to use the AcroView HFT
    "AVExpTObsolete1"
    "AVExpTObsolete2"
    "CosExpT"      ; Types, macros, structures, etc. required to use the Cos HFT

    "AVProcs"      ; Catalog of functions exported by AcroView
    ;; "AVCalls"

    ;; "PDProcs"   ; Catalog of functions exported by the PDModel HFT
    ;; "PDCalls"
    )
  "The list of involved Acrobat SDK header files in the right order.")

;; For each element in this list, when CDR is NIL, the corresponding FLI type is
;; given by (intern (string-upcase part) :keyword)
(defparameter *fli-types*
  '(("void")
    ("unsigned")
    ("signed")
    ("char"       :byte)
    ("short")
    ("int")
    ("long")
    ("float")
    ("double")
    ("size_t"     :size-t)
    ("intptr_t"   :intptr)
    ("uintptr_t"  :uintptr)
    ("__CFString" :cf-string) ; see ASExpT.h, line 2214
    ("struct"))) ; this last one is to be handled by *typedefs*

(defparameter *ignored-defines*
  '("boolean"))

;; These C macros are considered being defined as 1 in the SDK
(defparameter *positive-macros*
  '("PLUGIN"          ; Yes, we are building plugins!
    "HAS_MENUBAR" "HAS_FULL_SCREEN" "HAS_MENUS" "CAN_SELECT_GRAPHICS" ; used in AVProcs.h
    #+:macosx "MAC_PLATFORM"
    #+:win32  "WIN_PLATFORM"
    "defined(ACRO_SDK_LEVEL) || (ACRO_SDK_LEVEL < 2)"
    "PI_CORE_VERSION != 0"
    "ASUSE_OBSOLETE_TYPES"
    "USE_CPLUSPLUS_EXCEPTIONS_FOR_ASEXCEPTIONS"
    "NEW_PDFEDIT_HFTS"
    "NEW_PDSEDIT_HFTS"
    "PDMETADATA_HFT"
    "AS_ARCH_64BIT"
    "MAC_PLATFORM || (MAC_PLATFORM && !AS_ARCH_64BIT)"
    "defined(ACRO_SDK_LEVEL) || (ACRO_SDK_LEVEL < 0x00060000)"
    ))

;; These C macros are considered being defined as 0 in the SDK
(defparameter *negative-macros*
  '("DEBUG" "0"
    "TOOLKIT"
    "ACROBAT_LIBRARY" ; We are definitely NOT using Adobe PDFL
    "THREAD_SAFE_PDFL"
    "READER"          ; We are not building Reader plugins (but this is possible)
    "USE_NAMED_IDLE_PROCS"
    "USE_NAMED_LATE_INIT_PROCS"
    "HAS_32BIT_ATOMS"
    "BAD_SELECTOR"
    "UNIX_PLATFORM"
    #-:macosx "MAC_PLATFORM"
    #-:win32  "WIN_PLATFORM"
    "__cplusplus"
    "STATIC_HFT"
    "_WIN32"
    ))

(defvar *sdk-extern-location* nil
  "A pathname designator denoting where exactly Acrobat Pro SDK's
PluginSupport/Headers/API directory can be found.  You either set it here, or you'll get
a dialog asking for it.")

(defparameter *fli-file*
  (merge-pathnames "../fli.lisp"
                   (load-time-value
                    (or #.*compile-file-pathname* *load-pathname*)))
  "The target file \(to become a part of the PDF-PLUGIN-TOOLS
system) which is generated by this library.")

(defvar *hft-counter* 0
  "This variable records the offset of each API functions in the corresponding HFT")

(defvar *line-number* 0
  "The current line number when processing SDK headers in single-line mode.")

(defparameter *typedefs-init*
  '(((:pointer (:struct :cf-string)) . (:pointer :void)))
  "An alist which maps C typedefs to the `real' types.")

(defparameter *typedefs* nil
  "An alist which maps C typedefs to the `real' types.")
