## TheoryFeed — procedural NPC comment generator with rolling upvote animation.
## Placed as a VBoxContainer (TheoryFeedSection) inside result.tscn/HUD/Content.
## Call start(grade_idx, cryptid, zone) after _ready() to trigger the animation.

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
]

const SKEPTIC_HANDLES: Array = [
	"@dr_skeptic_phd", "@debunker_dan", "@critical_thinker",
	"@debunker_central", "@disappointed_dan", "@fake_news_finder",
]

const NEUTRAL_HANDLES: Array = [
	"@curious_carol", "@middle_ground_mike", "@fence_sitter_phil",
	"@maybe_believer", "@amateur_analyst",
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
	],
	1: [  # A — hot post
		"The movement matches every known {c} sighting report. Cannot debunk",
		"Not saying it's definitive but... absolutely saying it's definitive",
		"The {z} terrain is consistent with documented {c} habitat. Checks out",
		"Ran this through 3 enhancement tools. Cannot find a single artifact",
		"12 years a skeptic. This one actually got me",
	],
	2: [  # B — moderate
		"Interesting... this could definitely be something?",
		"I've seen worse. I've definitely seen much worse",
		"Jury's still out for me personally but I'm watching this space",
		"The blur actually makes it MORE authentic if you think about it",
		"Solid attempt. The {z} setting adds real credibility to this",
	],
	3: [  # C — mixed
		"The pixel analysis suggests significant manipulation. Sad",
		"I can literally see the seams on the costume",
		"I WANT to believe this but I just... I can't",
		"Extraordinary claims require extraordinary evidence. This is neither",
		"Points for effort, approximately zero points for actual evidence",
	],
	4: [  # D — mocked
		"That's clearly a person in a {c} suit. Halloween quality at best",
		"My 8-year-old could fake this with a phone and 10 minutes",
		"I drove 3 hours based on the sighting report for THIS Theory Feed post",
		"Not the {c} evidence that {z} researchers deserve",
		"47 seconds in any photo editor. We all see you",
	],
	5: [  # F — shown as moderation notices, not NPC comments
		"⚠  COMMUNITY MODERATION: Post flagged and removed",
		"@dr_skeptic_phd: Banned. As they absolutely should be",
		"This account is suspended for low-credibility posting",
	],
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


# ── Public API ────────────────────────────────────────────────────────────

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

	# Comments fade in with stagger
	for i in min(pool.size(), _comments.size()):
		var lbl: Label = _comments[i]
		lbl.text     = "%s: %s" % [
			handles[i % handles.size()],
			(pool[i] as String).replace("{c}", c).replace("{z}", z),
		]
		lbl.modulate = Color(1, 1, 1, 0)
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
