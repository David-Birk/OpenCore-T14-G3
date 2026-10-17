/* ThinkPad T14 G3 (Alder Lake): Processor-Objekte fuer macOS + plugin-type.
   Die Firmware definiert CPUs nur als ACPI0007-Devices (\_SB.PR00-PR3F),
   die macOS nicht als CPUs erkennt. Nur unter macOS aktiv. */
DefinitionBlock ("", "SSDT", 2, "CLAUDE", "CpuPlugA", 0x00003000)
{
    Scope (\_SB)
    {
        Processor (CP00, 0x00, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP01, 0x01, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP02, 0x02, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP03, 0x03, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP04, 0x04, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP05, 0x05, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP06, 0x06, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP07, 0x07, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP08, 0x08, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP09, 0x09, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP0A, 0x0A, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP0B, 0x0B, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP0C, 0x0C, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP0D, 0x0D, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP0E, 0x0E, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP0F, 0x0F, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP10, 0x10, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP11, 0x11, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP12, 0x12, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP13, 0x13, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP14, 0x14, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP15, 0x15, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP16, 0x16, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP17, 0x17, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP18, 0x18, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP19, 0x19, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP1A, 0x1A, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP1B, 0x1B, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP1C, 0x1C, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP1D, 0x1D, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP1E, 0x1E, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP1F, 0x1F, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP20, 0x20, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP21, 0x21, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP22, 0x22, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP23, 0x23, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP24, 0x24, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP25, 0x25, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP26, 0x26, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP27, 0x27, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP28, 0x28, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP29, 0x29, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP2A, 0x2A, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP2B, 0x2B, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP2C, 0x2C, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP2D, 0x2D, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP2E, 0x2E, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP2F, 0x2F, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP30, 0x30, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP31, 0x31, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP32, 0x32, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP33, 0x33, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP34, 0x34, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP35, 0x35, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP36, 0x36, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP37, 0x37, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP38, 0x38, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP39, 0x39, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP3A, 0x3A, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP3B, 0x3B, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP3C, 0x3C, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP3D, 0x3D, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP3E, 0x3E, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }

        Processor (CP3F, 0x3F, 0x00000000, 0x00)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }
    }

    Scope (\_SB.CP00)
    {
        Method (_DSM, 4, NotSerialized)
        {
            If (!Arg2) { Return (Buffer (One) { 0x03 }) }
            Return (Package (0x02) { "plugin-type", One })
        }
    }
}
