open util/ordering[DateTime]

sig DateTime {}

sig Tournament {
	, state: TournamentState
	, subscriptionDeadline: DateTime
	, battles: set Battle
	, subscriptions: set TournamentSubscription
} {
	// Sync the two relationships
	all b: Battle | (b in battles) <=> (b.tournament = this)
	// Sync the two relationships
	all s: TournamentSubscription | (s in subscriptions) <=> (s.tournament = this)
}

enum TournamentState { Subscribing, InProgress, TournamentDone }

sig Battle {
	, tournament: Tournament
	, state: BattleState
	//, description: String
	, minStudents: Int
	, maxStudents: Int
	, registrationDeadline: DateTime
	, submissionDeadline: DateTime
	, partecipations: set BattlePartecipation
} {
	// Min and max students constraints
	minStudents > 0 and minStudents <= maxStudents
	// Sync the two relationships
	all p: BattlePartecipation | (p in partecipations) <=> (p.battle = this)
}

enum BattleState { Registration, Submission, Consolidation, BattleDone }

sig Student {
	, receivedInvites: set Invite
	, sentInvites: set Invite
	, subscriptions: set TournamentSubscription
	, partecipations: set TeamPartecipation
} {
	// Sync the two relationships
	all i: Invite | (i in receivedInvites) <=> i.invitee = this
	// Sync the two relationships
	all i: Invite | (i in sentInvites) <=> i.inviter = this
	// Sync the two relationships
	all s: TournamentSubscription | (s in subscriptions) <=> s.student = this
	// Sync the two relationships
	all p: TeamPartecipation | (p in partecipations) <=> p.student = this
}

sig TournamentSubscription {
	, student: Student
	, tournament: Tournament
	, subscriptionDate: DateTime
	, score: Int
} {
	// Must be subscribed before the deadline
	lte[subscriptionDate, tournament.subscriptionDeadline]
}

sig Invite {
	, state: InviteState
	, inviter: Student
	, invitee: Student
	, teamParticipation: TeamPartecipation
} {
	// A student can't invite itself
	inviter != invitee
	// If the student has accepted, he must have a team
	state = Accepted implies (some t: TeamPartecipation | t.invite = this)
}

enum InviteState { Accepted, Rejected, Pending }

sig TeamPartecipation {
	, student: Student
	, invite: lone Invite
	, team: Team
	, studentCommits: Int
} {
	// If the student was invited: 
	(invite = none) or (
			// he must have been invited to this
			invite.teamParticipation = this
				// he must have accepted
				and invite.state = Accepted
				// the invitee must be the same as the student
				and invite.invitee = student)
}

sig Team {
	, partecipation: lone BattlePartecipation
	, teamPartecipations: set TeamPartecipation
} {
	// Sync the two relationships
	all tp: TeamPartecipation | (tp in teamPartecipations) <=> (tp.team = this)
	// There must be exactly one student which was not invited
	one p: TeamPartecipation | p.team = this and p.invite = none and (
		// All invited students must be invited by that student
		all p1: TeamPartecipation | (
				p != p1 and p1.team = this
			) implies (
				p1.invite != none and p1.invite.inviter = p.student
			)
	)
	
	// Can't have the same student twice in the same team
	all disj p1, p2: TeamPartecipation | (
			p1.team = this and p2.team = this
		) implies p1.student != p2.student
	// If there's the partecipation, all students must be 
	// subscribed to the tournament
	(partecipation = none) or (
		all st: Student, teamPart: TeamPartecipation | (
				st = teamPart.student and teamPart.team = this
			) implies (some subscription: TournamentSubscription |
				subscription.student = st 
					and subscription.tournament = partecipation.battle.tournament
			)
	)
	// If there's a partecipation, we must respect the battle requirements
	partecipation = none or (
			#teamPartecipations >= partecipation.battle.minStudents and 
				#teamPartecipations <= partecipation.battle.maxStudents
		)
}

sig BattlePartecipation {
	, team: Team
	, battle: Battle
	, registrationDate: DateTime
	, score: Int
} {
	// Sync the two relationships
	team.partecipation = this
	// There must be a team for this battle partecipation
	some team: Team | team.partecipation = this
	// Must be registered before the deadline
	lte[registrationDate, battle.registrationDeadline]
}

// A student must only be in one team at a time for each battle
fact studentInOneTeamPerBattle {
	all disj p1, p2: TeamPartecipation | (
			p1.student = p2.student 
				and p1.team.partecipation != none
				and p2.team.partecipation != none
		) implies (
			p1.team.partecipation.battle != p2.team.partecipation.battle
		)
}

run {
	some b: Battle | b.minStudents >= 3 and #b.partecipations >= 1
} for 10 but exactly 1 Battle
