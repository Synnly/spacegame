extends Area2D

@export var maxhealth = 200
@export var attack_damage = 50

@onready var health_count = $LifeBar/HealthCount
@onready var green_bar = $LifeBar/GreenBar

var health = maxhealth
var bodies_inside = []
var bodies_damage_taken = []
var knockback = 100

func _ready():
	health_count.text = str(maxhealth)

func _process(delta):
	for body in bodies_inside:	
		if body.name == "Player" and body not in bodies_damage_taken :	# if body is player, slow him down by damage inflicted
			var damage_taken = min(health, body.velocity.length())
			
			# Not enough speed, take damage and knockback			
			if health > body.velocity.length():
				body.health -= attack_damage
				body.velocity = (body.position - position).normalized() * knockback
				
			else:	
				body.velocity = body.velocity.normalized() * (body.velocity.length() - damage_taken)
			
			bodies_damage_taken.append(body)
			health -= damage_taken
			
	health_count.text = str(int(health))
	green_bar.scale.x = health/maxhealth
			
	if health <= 0:	# Die
		queue_free()

func _on_body_entered(body):
	bodies_inside.append(body)
	
func _on_body_exited(body):
	bodies_inside.erase(body)
	bodies_damage_taken.erase(body)
