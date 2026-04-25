## TheoryFeed — procedural NPC comment generator with rolling upvote animation.
## Placed as a VBoxContainer (TheoryFeedSection) inside result.tscn/HUD/Content.
## Call start(grade_idx, cryptid, zone) after _ready() to trigger the animation.
## NPC avatars (16×16 TextureRect children of each comment Label) auto-fade with parent.

class_name TheoryFeed
extends VBoxContainer

signal feed_complete

# ── Grade config ──────────────────────────────────────────────────────────
# Per grade: [upvotes_min, upvotes_max, downvotes_min, downvotes_max]
const UPVOTE_RANGES: Array = [
	[3000, 5500,   40,  150],   # S — viral
	[ 800, 1400,   90,  280],   # A — hot post
	[ 150,  380,   80,  210],   # B — moderate
	[  30,  140,  120,  380],   # C — mixed
	[   5,   45,  420, 1600],   # D — mocked
	[   0,    0,    0,    0],   # F — banned
]

const REP_DELTA: Array = [100, 60, 30, 10, -10, -20]

# ── NPC handles ───────────────────────────────────────────────────────────
const BELIEVER_HANDLES: Array = [
	"@cryptid_hunter_99", "@mothman_mike", "@truther_verified",
	"@bigfoot_academic", "@nightvision_nell",
	"@truth_is_out", "@zone_researcher", "@footage_analyst",
	"@definitely_not_cia", "@area51_intern",
	"@im_not_saying_its_aliens", "@classified_source",
]

const SKEPTIC_HANDLES: Array = [
	"@dr_skeptic_phd", "@debunker_dan", "@critical_thinker",
	"@debunker_central", "@disappointed_dan", "@fake_news_finder",
	"@peer_reviewed_bob", "@evidence_required",
]

const NEUTRAL_HANDLES: Array = [
	"@curious_carol", "@middle_ground_mike", "@fence_sitter_phil",
	"@maybe_believer", "@amateur_analyst",
	"@just_asking_questions", "@cryptid_adjacent", "@field_notes_only",
	"@thats_a_big_if", "@waiting_for_proof",
]

# ── Comment templates (5 per grade = 30 total) ────────────────────────────
# {c} = cryptid name, {z} = zone name  (both uppercased at runtime)
const TEMPLATES: Dictionary = {
	0: [  # S — viral
		"I'm SHAKING. This is the clearest {c} footage ever captured on this planet",
		"THE EYES. The eye shine from {z}. This is undeniable",
		"Sending this to every scientist who ever called me crazy",
		"I quit my job. I'm going to {z} to find it myself. Don't try to stop me",
		"Peer-reviewed. Submitting to the International Cryptid Journal immediately",
		"My hands are literally trembling right now. THE {c} IS REAL",
		"Called in sick tomorrow. Booking a flight to {z} first thing",
		"I have waited 23 years for footage this clear. This is it. This is THE one",
		"Screenshot saved. Printed. Laminated. Framed. Above my fireplace now",
		"The government is going to bury this. Screenshot everything RIGHT NOW",
	],
	1: [  # A — hot post
		"The movement matches every known {c} sighting report. Cannot debunk",
		"Not saying it's definitive but... absolutely saying it's definitive",
		"The {z} terrain is consistent with documented {c} habitat. Checks out",
		"Ran this through 3 enhancement tools. Cannot find a single artifact",
		"12 years a skeptic. This one actually got me",
		"The gait analysis alone puts this in the top 5 ever recorded for {c}",
		"I showed this to my professor. She said 'no comment.' That's basically confirmation",
		"Cross-referencing with the {z} incident reports from last fall. It lines up",
		"Forwarded this to 14 researchers. Seven replied within the hour. SEVEN",
		"I've been in the field for 8 years and this is the cleanest shot I've ever seen",
	],
	2: [  # B — moderate
		"Interesting... this could definitely be something?",
		"I've seen worse. I've definitely seen much worse",
		"Jury's still out for me personally but I'm watching this space",
		"The blur actually makes it MORE authentic if you think about it",
		"Solid attempt. The {z} setting adds real credibility to this",
		"I'm not convinced but I'm not NOT convinced either. Staying tuned",
		"That silhouette is doing something to my brain. Can't look away",
		"The {z} angle checks out at least. Location research was clearly done",
		"Borderline for me. If the next frame were a second longer I'd say A-grade",
		"Someone in my cryptid group said hoax. Someone else said breakthrough. We're split",
	],
	3: [  # C — mixed
		"The pixel analysis suggests significant manipulation. Sad",
		"I can literally see the seams on the costume",
		"I WANT to believe this but I just... I can't",
		"Extraordinary claims require extraordinary evidence. This is neither",
		"Points for effort, approximately zero points for actual evidence",
		"Lighting is wrong for {z} at this time of day. Do your research next time",
		"Scale analysis puts this creature at 4 feet tall. {c} is minimum 7. Nice try",
		"I want to believe. I really do. This is not helping me believe",
		"My nephew faked something better than this for a school project",
		"The posture is all wrong. {c} does not move like that and I will not accept this",
	],
	4: [  # D — mocked
		"That's clearly a person in a {c} suit. Halloween quality at best",
		"My 8-year-old could fake this with a phone and 10 minutes",
		"I drove 3 hours based on the sighting report for THIS Theory Feed post",
		"Not the {c} evidence that {z} researchers deserve",
		"47 seconds in any photo editor. We all see you",
		"The shadow is going the wrong direction. THE SHADOW IS GOING THE WRONG DIRECTION",
		"Posted to our Discord as a cautionary tale. Unanimous verdict: no",
		"I have eaten blurrier photos than this and produced better evidence",
		"Requesting this be added to the Theory Feed Hall of Shame immediately",
		"Points for the {z} location at least. Deducted for everything else",
	],
	5: [  # F — shown as moderation notices, not NPC comments
		"⚠  COMMUNITY MODERATION: Post flagged and removed",
		"@dr_skeptic_phd: Banned. As they absolutely should be",
		"This account is suspended for low-credibility posting",
	],
}

# ── Avatar handle → filename mapping ─────────────────────────────────────
const AVATAR_MAP: Dictionary = {
	"@cryptid_hunter_99":  "npc_cryptid_hunter",
	"@mothman_mike":       "npc_mothman_mike",
	"@truther_verified":   "npc_truther_verified",
	"@bigfoot_academic":   "npc_bigfoot_academic",
	"@nightvision_nell":   "npc_nightvision_nell",
	"@truth_is_out":       "npc_truth_is_out",
	"@zone_researcher":    "npc_zone_researcher",
	"@footage_analyst":    "npc_footage_analyst",
	"@dr_skeptic_phd":     "npc_dr_skeptic",
	"@debunker_dan":       "npc_debunker_dan",
	"@critical_thinker":   "npc_critical_thinker",
	"@debunker_central":   "npc_debunker_central",
	"@disappointed_dan":   "npc_disappointed_dan",
	"@fake_news_finder":   "npc_fake_news_finder",
	"@curious_carol":      "npc_curious_carol",
	"@middle_ground_mike": "npc_middle_ground",
	"@fence_sitter_phil":  "npc_fence_sitter",
	"@maybe_believer":     "npc_maybe_believer",
	"@amateur_analyst":    "npc_amateur_analyst",
}

# ── Node refs ─────────────────────────────────────────────────────────────
@onready var _header:     Label = $FeedHeader
@onready var _up_label:   Label = $UpvoteRow/UpLabel
@onready var _down_label: Label = $UpvoteRow/DownLabel
@onready var _comments: Array[Label] = [
	$FeedContainer/Comment0,
	$FeedContainer/Comment1,
	$FeedContainer/Comment2,
]

var _avatar_rects: Array[TextureRect] = []


# ── Public API ────────────────────────────────────────────────────────────

func _ready() -> void:
	for lbl: Label in _comments:
		var tr                      := TextureRect.new()
		tr.position                  = Vector2(-22.0, 2.0)
		tr.custom_minimum_size       = Vector2(16.0, 16.0)
		tr.stretch_mode              = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter              = Control.MOUSE_FILTER_IGNORE
		tr.texture                   = null
		lbl.add_child(tr)
		_avatar_rects.append(tr)


func get_top_comment() -> String:
	if _comments.is_empty():
		return ""
	return (_comments[0] as Label).text


func start(grade_idx: int, cryptid: String, zone: String) -> void:
	_reset()
	if grade_idx >= 5:
		_show_banned()
		return
	_animate(grade_idx, cryptid, zone)


# ── Internal ──────────────────────────────────────────────────────────────

func _reset() -> void:
	_header.text     = "── THEORY FEED ──"
	_header.modulate = Color(1, 1, 1, 1)
	_up_label.text   = "↑  0"
	_down_label.text = "↓  0"
	for lbl: Label in _comments:
		lbl.text     = ""
		lbl.modulate = Color(1, 1, 1, 0)
	for tr: TextureRect in _avatar_rects:
		tr.texture = null


func _show_banned() -> void:
	_header.text     = "⚠  THEORY FEED — SUSPENDED"
	_header.modulate = Color(0.90, 0.20, 0.15)
	_up_label.text   = ""
	_down_label.text = ""
	var msgs: Array = TEMPLATES[5]
	for i in _comments.size():
		var lbl: Label = _comments[i]
		lbl.text     = msgs[i] if i < msgs.size() else ""
		lbl.modulate = Color(0.90, 0.25, 0.20)
	feed_complete.emit()


func _animate(grade_idx: int, cryptid: String, zone: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var r: Array  = UPVOTE_RANGES[grade_idx]
	var target_up := rng.randi_range(r[0], r[1])
	var target_dn := rng.randi_range(r[2], r[3])

	var pool: Array = TEMPLATES[grade_idx].duplicate()
	pool.shuffle()
	var c := cryptid.to_upper()
	var z := zone.replace("_", " ").to_upper()

	var handles: Array = _handles_for(grade_idx).duplicate()
	handles.shuffle()

	_up_label.modulate   = Color(0.30, 0.90, 0.30)
	_down_label.modulate = Color(0.90, 0.25, 0.20) if grade_idx >= 3 \
	                       else Color(0.65, 0.65, 0.65, 0.70)

	# Rolling upvote/downvote counters
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(
		func(v: float) -> void: _up_label.text   = "↑  " + _fmt(int(v)),
		0.0, float(target_up), 2.0
	)
	tw.tween_method(
		func(v: float) -> void: _down_label.text = "↓  " + _fmt(int(v)),
		0.0, float(target_dn), 2.0
	)

	# Ping sounds at 0s, 0.5s, 1.0s, 1.5s, 2.0s across the roll
	AudioManager.play_sfx("feed_ping", -6.0)
	var ping_tw := create_tween()
	for _i in 4:
		ping_tw.tween_interval(0.5)
		ping_tw.tween_callback(func(): AudioManager.play_sfx("feed_ping", -10.0))

	# Comments fade in with stagger; avatar fades with parent via modulate cascade
	for i in min(pool.size(), _comments.size()):
		var lbl: Label    = _comments[i]
		var handle: String = handles[i % handles.size()]
		lbl.text     = "%s: %s" % [
			handle,
			(pool[i] as String).replace("{c}", c).replace("{z}", z),
		]
		lbl.modulate = Color(1, 1, 1, 0)
		_avatar_rects[i].texture = _load_avatar(handle)
		var tw2 := create_tween()
		tw2.tween_interval(0.35 + i * 0.45)
		tw2.tween_property(lbl, "modulate:a", 1.0, 0.30)

	await get_tree().create_timer(2.0).timeout
	feed_complete.emit()


func _handles_for(grade_idx: int) -> Array:
	match grade_idx:
		0, 1: return BELIEVER_HANDLES
		3, 4: return SKEPTIC_HANDLES
		_:    return NEUTRAL_HANDLES


static func _fmt(n: int) -> String:
	return "%.1fK" % (n / 1000.0) if n >= 1000 else str(n)


static func _load_avatar(handle: String) -> Texture2D:
	var key: String = AVATAR_MAP.get(handle, "") as String
	if key == "":
		return null
	var path := "res://resources/textures/npc_avatars/%s.png" % key
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
