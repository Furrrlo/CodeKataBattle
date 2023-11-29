open util/ordering[DateTime]

sig DateTime {}

sig Educator {
	, createdTournaments: set Tournament
	, allowedTournaments: set Tournament
	, battles: set Battle
	, badges: set Badge
} {
	// Sync the two relationships
	all t: Tournament | t in createdTournaments <=> t.creator = this
	// Sync the two relationships
	all t: Tournament | t in allowedTournaments <=> this in t.authorized
	// Sync the two relationships
	all b: Battle | b in battles <=> b.creator = this
	// Sync the two relationships
	all b: Badge | b in badges <=> b.creator = this
}

sig Badge {
	, creator: Educator
	, tournaments: set Tournament
	, title: String
	, condition: String
	, earners: set TournamentSubscription
} {
	title = "Title"
	condition = "predicate"
	// Sync the two relationships
	all t: Tournament | t in tournaments <=> this in t.badges
	// Sync the two relationships
	all ts: TournamentSubscription | ts in earners <=> this in ts.badges
}

sig Tournament {
	, creator: Educator
	, authorized: set Educator
	, state: TournamentState
	, subscriptionDeadline: DateTime
	, battles: set Battle
	, subscriptions: set TournamentSubscription
	, badges: set Badge
} {
	// Sync the two relationships
	all b: Battle | (b in battles) <=> (b.tournament = this)
	// Sync the two relationships
	all s: TournamentSubscription | (s in subscriptions) <=> (s.tournament = this)
}

enum TournamentState { Subscribing, InProgress, TournamentDone }

sig Battle {
	, creator: Educator
	, tournament: Tournament
	, state: BattleState
	, description: String
	, minStudents: Int
	, maxStudents: Int
	, registrationDeadline: DateTime
	, submissionDeadline: DateTime
	, partecipations: set BattlePartecipation
	, repo: lone Repository
} {
	description = "descr"
	// Min and max students constraints
	minStudents > 0 and minStudents <= maxStudents
	// Sync the two relationships
	all p: BattlePartecipation | (p in partecipations) <=> (p.battle = this)
	// Repo must exist after the registration state
	gt[state, Registration] <=> repo != none
	// creator must be tournament creator or authorized
	creator = tournament.creator or creator in tournament.authorized
	// Sync the two relationships
	repo != none <=> repo.battle = this
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
	, badges: set Badge
} {
	// Must be subscribed before the deadline
	lte[subscriptionDate, tournament.subscriptionDeadline]
	// If the tournament has not started yet, can't have badges
	lte[tournament.state, Subscribing] => not (some b: Badge | b in badges)
	// Earned badge must be defined for this tournament
	all b: Badge | b in badges => b in tournament.badges
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
	// The invited student must be the same partecipating
	teamParticipation.student = invitee
}

fact {
	// There cannot be two pending/accepted invites for the same team
	all disj i1, i2: Invite | (
			i1.teamParticipation = i2.teamParticipation and 
				i1.invitee = i2.invitee and 
				i1.state = Accepted
		) implies (
			i2.state != Accepted and i2.state != Pending
		)
	// If a student invited someone to a team, he must be the team creator
	all i: Invite | (some tp: TeamPartecipation | 
				tp != i.teamParticipation and 
					tp in i.teamParticipation.team.teamPartecipations and
					tp.invite = none and
					tp.student = i.inviter)
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
				// if already subscribed to a battle, he must have accepted
				and (team.partecipation != none => invite.state = Accepted)
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
	, repo: lone Repository
} {
	// Sync the two relationships
	team.partecipation = this
	// There must be a team for this battle partecipation
	some team: Team | team.partecipation = this
	// Must be registered before the deadline
	lte[registrationDate, battle.registrationDeadline]
	// Repo can only exist past the battle REGISTRATION state
	// (if the team created it on their own)
	repo != none => gt[battle.state, Registration]
	// Sync the two relationships
	repo != none <=> repo.battleParticipation = this
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

one sig Github {
	, repositories: set Repository
} {
	all r: Repository | r in repositories
}

sig Repository {
	, battle: lone Battle
	, battleParticipation: lone BattlePartecipation
} {
	// Sync the two fields
	battle != none <=> battle.repo = this
	// Sync the two fields
	battleParticipation != none <=> battleParticipation.repo = this
	// Must be used either by a battle or by a team
	battle != none or battleParticipation != none
	not (battle != none and battleParticipation != none)
}

/*
run {
    some b: Battle | b.minStudents >= 3 and #b.partecipations >= 1
} for 10 but exactly 1 Battle, exactly 2 Badge
*/

/*
run {
	#Battle = 1 
	some b: Battle | b.minStudents = 3 and 
					   b.maxStudents = 3 and 
					   #b.partecipations >= 1
	#Team = 2
	#Invite = 4
	some i: Invite | i.state = Rejected
	some i: Invite | i.state = Pending
	#Student = 4
	#Educator = 1
	#Badge = 0
} for 10
*/

run {
	#Student = 0 
	#Tournament = 2
	#Battle >= 3
	#Educator >= 3
	#Badge >= 2
} for 10


