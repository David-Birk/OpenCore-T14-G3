/* Schaltet unter macOS von AWAC (ACPI000E) auf die klassische RTC (PNP0B00) um,
   ueber die Firmware-Variable STAS. */
DefinitionBlock ("", "SSDT", 2, "CLAUDE", "AWAC", 0x00000000)
{
    External (STAS, FieldUnitObj)
    Scope (_SB)
    {
        Method (_INI, 0, NotSerialized)
        {
            If (_OSI ("Darwin")) { STAS = One }
        }
    }
}
