extends KinematicBody2D

const TARGET_FPS = 60
const ACCELERATION = 20
const MAX_SPEED = 182
const FRICTION = 35
const AIR_RESISTANCE = 1
const GRAVITY = 7
const JUMP_HEIGHT = 250

var jumpWasPressed = false
var timeOffGround = 0
var jumpForgiveness = .5

onready var motion = Vector2.ZERO

onready var sprite = $Sprite
onready var animationPlayer = $AnimationPlayer

var jumpAnimationPlayed = false
var fallAnimationPlayed = false

var respawnPoint = Vector2.ZERO

var isJumping = false

var canJumpEvenThoughOffGround = true
var fallMultiplier = 2

var landSoundPlayed;
onready var audioPlayer = $"Floor Checker/landingSound"

var canJump = false
var jumping

var paused = false

var climbing = false

func _ready():
	move_and_slide(Vector2(10,0), Vector2.UP, true)
	$Camera2D/CanvasLayer/RichTextLabel.OnUIChange(Score.score)
	var font = DynamicFont.new()
	font.font_data = load("res://Fonts/PoppkornRegular-MzKY.ttf")
	$Camera2D/CanvasLayer/RichTextLabel.set("custom_fonts/font", font)
	respawnPoint = global_position

	if animationPlayer != null:
		animationPlayer.play("Idle")

func animate():
	if is_on_floor() and is_zero_approx(motion.x):
		jumpAnimationPlayed = false
		fallAnimationPlayed = false
		animationPlayer.play("Idle")
	elif is_on_floor() and motion.x != 0:
		jumpAnimationPlayed = false
		fallAnimationPlayed = false
		animationPlayer.play("Run")
	elif !is_on_floor() and motion.y < 0 and !jumpAnimationPlayed:
		jumpAnimationPlayed = true
		fallAnimationPlayed = false
		animationPlayer.play("Jump")
		pass
	elif !is_on_floor() and motion.y > 0.2 and !fallAnimationPlayed and (timeOffGround > jumpForgiveness):
		fallAnimationPlayed = true
		animationPlayer.play("Fall")
		pass
	elif climbing and motion.y >= 0:
		animationPlayer.play("Idle_Climb")
	elif climbing and motion.y < 0:
		animationPlayer.play("Climb")

func Respawn():
	global_position = respawnPoint


func _physics_process(delta):
	if Input.is_action_just_pressed("jump"):
		jumping = true
	if !climbing:
		motion.y += GRAVITY * delta * TARGET_FPS
		horizontal(delta)
	if jumping:
		Jump()
	animate()
	if climbing:
		vertical()

func horizontal(delta):
	var x_input = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if x_input != 0:
		motion.x += x_input * ACCELERATION * delta * TARGET_FPS
		motion.x = clamp(motion.x, -MAX_SPEED, MAX_SPEED)
		sprite.flip_h = x_input < 0
	if is_on_floor():
		if is_zero_approx(x_input):
			motion.x = _apply_drag(motion.x, FRICTION, delta)
	else:
		if is_zero_approx(x_input):
			motion.x = _apply_drag(motion.x, AIR_RESISTANCE, delta)
	
	#moving platforms
	for i in get_slide_count():
		var collision = get_slide_collision(i)
		if collision.collider.has_method("collide_with"):
			collision.collider.collide_with(collision, self)
	
	motion = move_and_slide(motion, Vector2.UP)

func Jump():
	if !is_on_floor():
		landSoundPlayed = false;
		CoyoteTime()
	
	if is_on_floor():
		if landSoundPlayed == false:
			audioPlayer.play()
		landSoundPlayed = true
		canJumpEvenThoughOffGround = true
		if jumpWasPressed == true:
			motion.y -= JUMP_HEIGHT
			
	if Input.is_action_just_pressed("jump"):
		jumpWasPressed = true
		RememberJumpTime()
		if canJumpEvenThoughOffGround:
			motion.y -= JUMP_HEIGHT
	
	if motion.y > 0:
		motion += Vector2.UP  * -4
		if animationPlayer != null:
			animationPlayer.play("Fall")

func _apply_drag(_motion, factor, delta):
	return lerp(_motion, 0, factor * delta)

func CoyoteTime():
	yield(get_tree().create_timer(.1), "timeout")
	canJumpEvenThoughOffGround = false
	pass

func RememberJumpTime():
	yield(get_tree().create_timer(.1), "timeout")
	jumpWasPressed = false
	pass

func vertical():
	if Input.is_action_pressed("Up"):
		motion.y = -MAX_SPEED / 2
	elif Input.is_action_pressed("Down"):
		motion.y = 0.75 * MAX_SPEED
	

func climb_rope():
	climbing = true
	motion.x = 0

var ropes := 0

func on_interact_entered(obj_pos: Vector2, type):
	if type == 1:
		ropes += 1
		if !is_on_floor():
			global_position.x = obj_pos.x
			climb_rope()

	elif type == 3:
		Score.score+= 1
		$Camera2D/CanvasLayer/RichTextLabel.OnUIChange(Score.score)
		$"Collect Sound Effect".play()
		SaveSystem.save()

func on_interact_exited(obj_pos: Vector2, type):
	if type == 1:
		ropes = max(0, ropes - 1)
		if ropes == 0 and climbing:
			climbing = false
