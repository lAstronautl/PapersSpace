extends RigidBody2D

var assignedLabel = ""

func applyLabelTo(target: RigidBody2D) -> bool:
	if assignedLabel.length() == 0:
		return false
	target.name = assignedLabel
	return true
