extends RigidBody2D

const maxAmount = 30

var currentAmount: int = maxAmount

# Unlike SS14's refillable TonerCartridge (which drains gradually across
# multiple printers/uses), this cartridge is single-use: its entire charge is
# dumped into the printer in one go and it's spent, even if some of that
# charge overflows past the printer's remaining capacity and is wasted.
func refillInto(printer) -> int:
	var transferred = min(currentAmount, printer.maxToner - printer.toner)
	printer.toner += transferred
	currentAmount = 0
	return transferred
