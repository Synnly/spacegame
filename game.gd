extends Node2D

@onready var wb_haut = $WB_haut
@onready var wb_bas = $WB_bas
@onready var wb_gauche = $WB_gauche
@onready var wb_droite = $WB_droite

const X_MARGIN = 2500
const Y_MARGIN = 2500
var game_paused = false

# Called when the node enters the scene tree for the first time.
func _ready():
	wb_haut.position = Vector2(0, -Y_MARGIN)
	wb_bas.position = Vector2(0, Y_MARGIN)
	wb_gauche.position = Vector2(-X_MARGIN, 0)
	wb_droite.position = Vector2(X_MARGIN, 0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
