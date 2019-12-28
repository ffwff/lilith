module X86
  extend self

  module CPUID
    extend self

    # Executes the `cpuid` instruction with EAX set to `code`, and return the values in EAX, EBX, ECX, EDX as a tuple.
    def cpuid(code : UInt32) : Tuple(UInt32, UInt32, UInt32, UInt32)
      a = 0u32
      b = 0u32
      c = 0u32
      d = 0u32
      asm("cpuid"
              : "={eax}"(a), "={ebx}"(b), "={ecx}"(c), "={edx}"(d)
              : "{eax}"(code)
              : "volatile")
      {a, b, c, d}
    end

    INTEL_MAGIC = 0x756e6547
    AMD_MAGIC   = 0x68747541

    # Features specified in the ECX register.
    @[Flags]
    enum FeaturesEcx : UInt32
      SSE3    = 1 << 0
      PCLMUL  = 1 << 1
      DTES64  = 1 << 2
      MONITOR = 1 << 3
      DS_CPL  = 1 << 4
      VMX     = 1 << 5
      SMX     = 1 << 6
      EST     = 1 << 7
      TM2     = 1 << 8
      SSSE3   = 1 << 9
      CID     = 1 << 10
      FMA     = 1 << 12
      CX16    = 1 << 13
      ETPRD   = 1 << 14
      PDCM    = 1 << 15
      PCIDE   = 1 << 17
      DCA     = 1 << 18
      SSE4_1  = 1 << 19
      SSE4_2  = 1 << 20
      X2APIC  = 1 << 21
      MOVBE   = 1 << 22
      POPCNT  = 1 << 23
      AES     = 1 << 25
      XSAVE   = 1 << 26
      OSXSAVE = 1 << 27
      AVX     = 1 << 28
    end

    # Features specified in the EDX register.
    @[Flags]
    enum FeaturesEdx : UInt32
      FPU   = 1 << 0
      VME   = 1 << 1
      DE    = 1 << 2
      PSE   = 1 << 3
      TSC   = 1 << 4
      MSR   = 1 << 5
      PAE   = 1 << 6
      MCE   = 1 << 7
      CX8   = 1 << 8
      APIC  = 1 << 9
      SEP   = 1 << 11
      MTRR  = 1 << 12
      PGE   = 1 << 13
      MCA   = 1 << 14
      CMOV  = 1 << 15
      PAT   = 1 << 16
      PSE36 = 1 << 17
      PSN   = 1 << 18
      CLF   = 1 << 19
      DTES  = 1 << 21
      ACPI  = 1 << 22
      MMX   = 1 << 23
      FXSR  = 1 << 24
      SSE   = 1 << 25
      SSE2  = 1 << 26
      SS    = 1 << 27
      HTT   = 1 << 28
      TM1   = 1 << 29
      IA64  = 1 << 30
      PBE   = 1 << 31
    end

    # Extended features specified in the ECX register.
    @[Flags]
    enum FeaturesExtendedEcx : UInt32
      LAHF_LM      = 1 << 0
      CMP_LEGACY   = 1 << 1
      SVM          = 1 << 2
      EXTAPIC      = 1 << 3
      CR8_LEGACY   = 1 << 4
      ABM          = 1 << 5
      SSE4a        = 1 << 6
      MISALIGN_SSE = 1 << 7
      PREFETCHW    = 1 << 8
      OSVW         = 1 << 9
      IBS          = 1 << 10
      XOP          = 1 << 11
      SKINIT       = 1 << 12
      WDT          = 1 << 13
      LWP          = 1 << 15
      FMA4         = 1 << 16
      TCE          = 1 << 17
      NODEID_MSR   = 1 << 19
      TBM          = 1 << 21
      TOPOEXT      = 1 << 22
      PERFCTR_CORE = 1 << 23
      PERFCTR_NB   = 1 << 24
      DBX          = 1 << 26
      PERFTSC      = 1 << 27
      PCX_L2I      = 1 << 28
    end

    # Extended features specified in the EDX register.
    @[Flags]
    enum FeaturesExtendedEdx : UInt32
      FPU           = 1 << 0
      VME           = 1 << 1
      DE            = 1 << 2
      PSE           = 1 << 3
      TSC           = 1 << 4
      MSR           = 1 << 5
      PAE           = 1 << 6
      MCE           = 1 << 7
      CX8           = 1 << 8
      APIC          = 1 << 9
      SYSCALL       = 1 << 11
      MTRR          = 1 << 12
      PGE           = 1 << 13
      MCA           = 1 << 14
      CMOV          = 1 << 15
      PAT           = 1 << 16
      PSE36         = 1 << 17
      MP            = 1 << 19
      NX            = 1 << 20
      MMXEXT        = 1 << 22
      MMX           = 1 << 23
      FXSR          = 1 << 24
      FXSR_OPT      = 1 << 25
      PDPE1GB       = 1 << 26
      RDTSCP        = 1 << 27
      LONG_MODE     = 1 << 29
      AMD_3DNOW_EXT = 1 << 30
      AMD_3DNOW     = 1 << 31
    end

    @@features_ecx = FeaturesEcx::None
    @@features_edx = FeaturesEdx::None

    @@features_ext_ecx = FeaturesExtendedEcx::None
    @@features_ext_edx = FeaturesExtendedEdx::None

    private def detect_features
      _, _, c, d = cpuid(1)
      @@features_ecx = FeaturesEcx.new c
      @@features_edx = FeaturesEdx.new d
    end

    private def detect_features_extended
      _, _, c, d = cpuid(0x80000001)
      @@features_ext_ecx = FeaturesExtendedEcx.new c
      @@features_ext_edx = FeaturesExtendedEdx.new d
    end

    # Gets CPU's features flags specified in ECX
    def features_ecx
      detect_features if @@features_ecx == FeaturesEcx::None
      @@features_ecx
    end

    # Gets CPU's features flags specified in EDX
    def features_edx
      detect_features if @@features_edx == FeaturesEdx::None
      @@features_edx
    end

    # Gets CPU's extended features flags specified in EDX
    def features_ext_ecx
      detect_features_extended if @@features_ext_ecx == FeaturesExtendedEcx::None
      @@features_ext_ecx
    end

    # Gets CPU's extended features flags specified in EDX
    def features_ext_edx
      detect_features_extended if @@features_ext_edx == FeaturesExtendedEdx::None
      @@features_ext_edx
    end

    # Checks CPU's flags specified in ECX contains a specific flag.
    def has_feature?(feature : FeaturesEcx)
      features_ecx.includes?(feature)
    end

    # Checks CPU's features flags specified in EDX contains a specific flag.
    def has_feature?(feature : FeaturesEdx)
      features_edx.includes?(feature)
    end

    # Checks CPU's extended features flags specified in ECX contains a specific flag.
    def has_feature?(feature : FeaturesExtendedEcx)
      features_ext_ecx.includes?(feature)
    end

    # Checks CPU's extended features flags specified in EDX contains a specific flag.
    def has_feature?(feature : FeaturesExtendedEdx)
      features_ext_edx.includes?(feature)
    end
  end
end
