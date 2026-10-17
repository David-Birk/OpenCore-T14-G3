/* Benoetigt den ACPI-Patch _OSI -> XOSI (nur DSDT). Meldet der Firmware unter macOS
   "Windows 2015", damit OSYS >= 0x07DC wird. Sonst liefert TPD0._CRS (Trackpad) keine
   I2C-Ressource zurueck und VoodooI2C findet das Trackpad nicht. */
DefinitionBlock ("", "SSDT", 2, "CLAUDE", "XOSI", 0x00001000)
{
    Method (XOSI, 1, NotSerialized)
    {
        Local0 = Package ()
        {
            "Windows 2001", "Windows 2001.1", "Windows 2001 SP1", "Windows 2001 SP2",
            "Windows 2006", "Windows 2006 SP1", "Windows 2006.1", "Windows 2009",
            "Windows 2012", "Windows 2013", "Windows 2015"
        }
        If (_OSI ("Darwin"))
        {
            Return ((Ones != Match (Local0, MEQ, Arg0, MTR, Zero, Zero)))
        }
        Return (_OSI (Arg0))
    }
}
