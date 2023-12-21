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
	, participations: set BattleParticipation
	, repo: lone Repository
} {
	description = "descr"
	// Min and max students constraints
	minStudents > 0 and minStudents <= maxStudents
	// Sync the two relationships
	all p: BattleParticipation | (p in participations) <=> (p.battle = this)
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
	, participations: set TeamParticipation
} {
	// Sync the two relationships
	all i: Invite | (i in receivedInvites) <=> i.invitee = this
	// Sync the two relationships
	all i: Invite | (i in sentInvites) <=> i.inviter = this
	// Sync the two relationships
	all s: TournamentSubscription | (s in subscriptions) <=> s.student = this
	// Sync the two relationships
	all p: TeamParticipation | (p in participations) <=> p.student = this
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
	, teamParticipation: TeamParticipation
} {
	// A student can't invite itself
	inviter != invitee
	// If the student has accepted, he must have a team
	state = Accepted implies (some t: TeamParticipation | t.invite = this)
	// The invited student must be the same participating
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
	all i: Invite | (some tp: TeamParticipation | 
				tp != i.teamParticipation and 
					tp in i.teamParticipation.team.teamParticipations and
					tp.invite = none and
					tp.student = i.inviter)
}

enum InviteState { Accepted, Rejected, Pending }

sig TeamParticipation {
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
				and (team.participation != none => invite.state = Accepted)
				// the invitee must be the same as the student
				and invite.invitee = student)
}

sig Team {
	, participation: lone BattleParticipation
	, teamParticipations: set TeamParticipation
} {
	// Sync the two relationships
	all tp: TeamParticipation | (tp in teamParticipations) <=> (tp.team = this)
	// There must be exactly one student which was not invited
	one p: TeamParticipation | p.team = this and p.invite = none and (
		// All invited students must be invited by that student
		all p1: TeamParticipation | (
				p != p1 and p1.team = this
			) implies (
				p1.invite != none and p1.invite.inviter = p.student
			)
	)
	
	// Can't have the same student twice in the same team
	all disj p1, p2: TeamParticipation | (
			p1.team = this and p2.team = this
		) implies p1.student != p2.student
	// If there's the participation, all students must be 
	// subscribed to the tournament
	(participation = none) or (
		all st: Student, teamPart: TeamParticipation | (
				st = teamPart.student and teamPart.team = this
			) implies (some subscription: TournamentSubscription |
				subscription.student = st 
					and subscription.tournament = participation.battle.tournament
			)
	)
	// If there's a participation, we must respect the battle requirements
	participation = none or (
			#teamParticipations >= participation.battle.minStudents and 
				#teamParticipations <= participation.battle.maxStudents
		)
}

sig BattleParticipation {
	, team: Team
	, battle: Battle
	, registrationDate: DateTime
	, score: Int
	, repo: lone Repository
} {
	// Sync the two relationships
	team.participation = this
	// There must be a team for this battle participation
	some team: Team | team.participation = this
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
	all disj p1, p2: TeamParticipation | (
			p1.student = p2.student 
				and p1.team.participation != none
				and p2.team.participation != none
		) implies (
			p1.team.participation.battle != p2.team.participation.battle
		)
}

one sig Github {
	, repositories: set Repository
} {
	all r: Repository | r in repositories
}

sig Repository {
	, battle: lone Battle
	, battleParticipation: lone BattleParticipation
} {
	// Sync the two fields
	battle != none <=> battle.repo = this
	// Sync the two fields
	battleParticipation != none <=> battleParticipation.repo = this
	// Must be used either by a battle or by a team
	battle != none or battleParticipation != none
	not (battle != none and battleParticipation != none)
}
