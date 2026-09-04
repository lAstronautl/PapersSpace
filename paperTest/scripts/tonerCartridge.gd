extends RigidBody2D

const maxAmount = 30

var currentAmount: int = maxAmount

# Mirrors SS14's TonerCartridgeSystem: refilling transfers min(cartridge's
# remaining amount, space left in the printer) into the printer, draining
# the cartridge itself rather than instantly topping the printer off for free.
func refillInto(printer) -> int:
	var space = printer.maxToner - printer.toner
	var transferred = min(currentAmount, space)
	currentAmount -= transferred
	printer.toner += transferred
	return transferred
