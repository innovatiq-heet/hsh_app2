class AlumniProfileModel {
  final int studentId;
  final String name;
  final String phone;
  final String email;
  final String degree;
  final String fieldOfStudy;
  final int? graduationYear;
  final String pastRoomNumber;
  final String yearsStayed;
  final String currentCompany;
  final String currentDesignation;
  final String currentCity;
  final String currentCountry;
  final String linkedinUrl;
  final String githubUrl;
  final String bio;
  final String avatarUrl;
  final bool isMentor;
  final String mentorshipTopics;
  final bool isVerified;
  final bool isPublic;

  const AlumniProfileModel({
    required this.studentId,
    required this.name,
    this.phone = '',
    this.email = '',
    this.degree = '',
    this.fieldOfStudy = '',
    this.graduationYear,
    this.pastRoomNumber = '',
    this.yearsStayed = '',
    this.currentCompany = '',
    this.currentDesignation = '',
    this.currentCity = '',
    this.currentCountry = 'India',
    this.linkedinUrl = '',
    this.githubUrl = '',
    this.bio = '',
    this.avatarUrl = '',
    this.isMentor = false,
    this.mentorshipTopics = '',
    this.isVerified = true,
    this.isPublic = true,
  });

  String get batchLabel => graduationYear != null ? 'Batch of $graduationYear' : 'Hostel Alumnus';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'A';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  bool get hasLinkedIn => linkedinUrl.trim().isNotEmpty;

  String get currentRoleLine {
    if (currentDesignation.isNotEmpty && currentCompany.isNotEmpty) {
      return '$currentDesignation at $currentCompany';
    }
    if (currentDesignation.isNotEmpty) return currentDesignation;
    if (currentCompany.isNotEmpty) return 'Working at $currentCompany';
    return '';
  }

  List<String> get topicsList {
    if (mentorshipTopics.trim().isEmpty) return [];
    return mentorshipTopics
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  factory AlumniProfileModel.fromJson(Map<String, dynamic> json) {
    return AlumniProfileModel(
      studentId: int.tryParse(json['student_id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      phone: json['phone_number']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      degree: json['degree']?.toString() ?? '',
      fieldOfStudy: json['field_of_study']?.toString() ?? '',
      graduationYear: int.tryParse(json['graduation_year']?.toString() ?? ''),
      pastRoomNumber: json['past_room_number']?.toString() ?? '',
      yearsStayed: json['years_stayed']?.toString() ?? '',
      currentCompany: json['current_company']?.toString() ?? '',
      currentDesignation: json['current_designation']?.toString() ?? '',
      currentCity: json['current_city']?.toString() ?? '',
      currentCountry: json['current_country']?.toString() ?? 'India',
      linkedinUrl: json['linkedin_url']?.toString() ?? '',
      githubUrl: json['github_url']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? '',
      isMentor: json['is_mentor'] == 1 || json['is_mentor'] == true || json['is_mentor'] == '1',
      mentorshipTopics: json['mentorship_topics']?.toString() ?? '',
      isVerified: json['is_verified'] != 0 && json['is_verified'] != false,
      isPublic: json['is_public'] != 0 && json['is_public'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'name': name,
    'phone_number': phone,
    'email': email,
    'degree': degree,
    'field_of_study': fieldOfStudy,
    'graduation_year': graduationYear,
    'past_room_number': pastRoomNumber,
    'years_stayed': yearsStayed,
    'current_company': currentCompany,
    'current_designation': currentDesignation,
    'current_city': currentCity,
    'current_country': currentCountry,
    'linkedin_url': linkedinUrl,
    'github_url': githubUrl,
    'bio': bio,
    'avatar_url': avatarUrl,
    'is_mentor': isMentor,
    'mentorship_topics': mentorshipTopics,
    'is_verified': isVerified,
    'is_public': isPublic,
  };
}

class AlumniEventModel {
  final int id;
  final String title;
  final String description;
  final String eventType;
  final DateTime eventDate;
  final String venue;
  final bool isOnline;
  final String? meetingLink;
  final String? bannerUrl;
  final String? myRsvpStatus;
  final int myGuestsCount;
  final String? myNotes;
  final int totalAttending;

  const AlumniEventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.eventType,
    required this.eventDate,
    required this.venue,
    required this.isOnline,
    this.meetingLink,
    this.bannerUrl,
    this.myRsvpStatus,
    this.myGuestsCount = 0,
    this.myNotes,
    this.totalAttending = 0,
  });

  bool get isUpcoming => eventDate.isAfter(DateTime.now());

  String get eventTypeDisplay {
    switch (eventType.toLowerCase()) {
      case 'reunion':
        return 'Reunion';
      case 'sabha':
        return 'Sabha & Guidance';
      case 'meetup':
        return 'Meetup';
      case 'annual_function':
        return 'Annual Function';
      default:
        return 'Hostel Event';
    }
  }

  factory AlumniEventModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate = DateTime.now();
    if (json['event_date'] != null) {
      try {
        parsedDate = DateTime.parse(json['event_date'].toString());
      } catch (_) {}
    }

    return AlumniEventModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? 'reunion',
      eventDate: parsedDate,
      venue: json['venue']?.toString() ?? '',
      isOnline: json['is_online'] == 1 || json['is_online'] == true || json['is_online'] == '1',
      meetingLink: json['meeting_link']?.toString(),
      bannerUrl: json['banner_url']?.toString(),
      myRsvpStatus: json['my_rsvp_status']?.toString(),
      myGuestsCount: int.tryParse(json['my_guests_count']?.toString() ?? '0') ?? 0,
      myNotes: json['my_notes']?.toString(),
      totalAttending: int.tryParse(json['total_attending']?.toString() ?? '0') ?? 0,
    );
  }
}

class AlumniJobModel {
  final int id;
  final int postedByStudentId;
  final String postedByName;
  final String posterDesignation;
  final String posterCompany;
  final int? posterGraduationYear;
  final String? posterLinkedin;
  final String title;
  final String company;
  final String jobType;
  final String location;
  final bool isRemote;
  final String experienceRequired;
  final String description;
  final String? requirements;
  final String? applyUrl;
  final String? contactEmail;
  final DateTime createdAt;

  const AlumniJobModel({
    required this.id,
    required this.postedByStudentId,
    required this.postedByName,
    this.posterDesignation = '',
    this.posterCompany = '',
    this.posterGraduationYear,
    this.posterLinkedin,
    required this.title,
    required this.company,
    required this.jobType,
    required this.location,
    required this.isRemote,
    this.experienceRequired = '',
    required this.description,
    this.requirements,
    this.applyUrl,
    this.contactEmail,
    required this.createdAt,
  });

  String get jobTypeDisplay {
    switch (jobType.toLowerCase()) {
      case 'referral':
        return 'Alumni Referral';
      case 'internship':
        return 'Internship';
      case 'part-time':
        return 'Part-time';
      default:
        return 'Full-time';
    }
  }

  factory AlumniJobModel.fromJson(Map<String, dynamic> json) {
    DateTime created = DateTime.now();
    if (json['created_at'] != null) {
      try {
        created = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }

    return AlumniJobModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      postedByStudentId: int.tryParse(json['posted_by_student_id']?.toString() ?? '0') ?? 0,
      postedByName: json['posted_by_name']?.toString() ?? 'Alumnus',
      posterDesignation: json['poster_designation']?.toString() ?? '',
      posterCompany: json['poster_current_company']?.toString() ?? '',
      posterGraduationYear: int.tryParse(json['poster_graduation_year']?.toString() ?? ''),
      posterLinkedin: json['poster_linkedin']?.toString(),
      title: json['title']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      jobType: json['job_type']?.toString() ?? 'full-time',
      location: json['location']?.toString() ?? '',
      isRemote: json['is_remote'] == 1 || json['is_remote'] == true || json['is_remote'] == '1',
      experienceRequired: json['experience_required']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      requirements: json['requirements']?.toString(),
      applyUrl: json['apply_url']?.toString(),
      contactEmail: json['contact_email']?.toString(),
      createdAt: created,
    );
  }
}

class AlumniMentorshipRequestModel {
  final int id;
  final int mentorStudentId;
  final String mentorName;
  final String mentorCompany;
  final String mentorDesignation;
  final String? mentorLinkedin;
  final int requesterStudentId;
  final String requesterName;
  final String requesterRoom;
  final String requesterPhone;
  final String topic;
  final String message;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const AlumniMentorshipRequestModel({
    required this.id,
    required this.mentorStudentId,
    this.mentorName = '',
    this.mentorCompany = '',
    this.mentorDesignation = '',
    this.mentorLinkedin,
    required this.requesterStudentId,
    this.requesterName = '',
    this.requesterRoom = '',
    this.requesterPhone = '',
    required this.topic,
    required this.message,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory AlumniMentorshipRequestModel.fromJson(Map<String, dynamic> json) {
    DateTime created = DateTime.now();
    if (json['created_at'] != null) {
      try {
        created = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }

    return AlumniMentorshipRequestModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      mentorStudentId: int.tryParse(json['mentor_student_id']?.toString() ?? '0') ?? 0,
      mentorName: json['mentor_name']?.toString() ?? '',
      mentorCompany: json['mentor_company']?.toString() ?? '',
      mentorDesignation: json['mentor_designation']?.toString() ?? '',
      mentorLinkedin: json['mentor_linkedin']?.toString(),
      requesterStudentId: int.tryParse(json['requester_student_id']?.toString() ?? '0') ?? 0,
      requesterName: json['requester_name']?.toString() ?? '',
      requesterRoom: json['requester_room']?.toString() ?? '',
      requesterPhone: json['requester_phone']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      notes: json['notes']?.toString(),
      createdAt: created,
    );
  }
}

class HostelNewsModel {
  final int id;
  final String title;
  final String category;
  final String content;
  final String? imageUrl;
  final double? targetAmount;
  final double raisedAmount;
  final String? initiativeLink;
  final DateTime createdAt;

  const HostelNewsModel({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    this.imageUrl,
    this.targetAmount,
    this.raisedAmount = 0.0,
    this.initiativeLink,
    required this.createdAt,
  });

  double get progressPercentage {
    if (targetAmount == null || targetAmount! <= 0) return 0.0;
    return (raisedAmount / targetAmount!).clamp(0.0, 1.0);
  }

  String get categoryDisplay {
    switch (category.toLowerCase()) {
      case 'renovation':
        return 'Renovation';
      case 'achievement':
        return 'Achievement';
      case 'initiative':
        return 'Voluntary Initiative';
      default:
        return 'Hostel News';
    }
  }

  factory HostelNewsModel.fromJson(Map<String, dynamic> json) {
    DateTime created = DateTime.now();
    if (json['created_at'] != null) {
      try {
        created = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }

    return HostelNewsModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'news',
      content: json['content']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      targetAmount: json['target_amount'] != null
          ? double.tryParse(json['target_amount'].toString())
          : null,
      raisedAmount: double.tryParse(json['raised_amount']?.toString() ?? '0') ?? 0.0,
      initiativeLink: json['initiative_link']?.toString(),
      createdAt: created,
    );
  }
}


class AlumniRsvpAttendeeModel {
  final int id;
  final int eventId;
  final int studentId;
  final String status;
  final int guestsCount;
  final String notes;
  final String studentName;
  final String studentCode;
  final String roomNumber;
  final String phoneNumber;
  final String currentCompany;
  final String currentDesignation;
  final int? graduationYear;
  final DateTime createdAt;

  const AlumniRsvpAttendeeModel({
    required this.id,
    required this.eventId,
    required this.studentId,
    required this.status,
    required this.guestsCount,
    required this.notes,
    required this.studentName,
    required this.studentCode,
    required this.roomNumber,
    required this.phoneNumber,
    required this.currentCompany,
    required this.currentDesignation,
    this.graduationYear,
    required this.createdAt,
  });

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'attending':
        return 'Going';
      case 'tentative':
        return 'Maybe';
      case 'declined':
        return 'Can\'t Go';
      default:
        return status;
    }
  }

  factory AlumniRsvpAttendeeModel.fromJson(Map<String, dynamic> json) {
    DateTime created = DateTime.now();
    if (json['created_at'] != null) {
      try {
        created = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }

    return AlumniRsvpAttendeeModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      eventId: int.tryParse(json['event_id']?.toString() ?? '0') ?? 0,
      studentId: int.tryParse(json['student_id']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'attending',
      guestsCount: int.tryParse(json['guests_count']?.toString() ?? '0') ?? 0,
      notes: json['notes']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Alumnus',
      studentCode: json['student_code']?.toString() ?? '',
      roomNumber: json['room_number']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      currentCompany: json['current_company']?.toString() ?? '',
      currentDesignation: json['current_designation']?.toString() ?? '',
      graduationYear: json['graduation_year'] != null
          ? int.tryParse(json['graduation_year'].toString())
          : null,
      createdAt: created,
    );
  }
}

class AlumniAdminStatsModel {
  final int totalAlumni;
  final int verifiedAlumni;
  final int activeMentors;
  final int upcomingEvents;
  final int totalRsvps;
  final int activeJobs;
  final int activeInitiatives;
  final double totalRaised;
  final int totalMentorshipRequests;

  const AlumniAdminStatsModel({
    this.totalAlumni = 0,
    this.verifiedAlumni = 0,
    this.activeMentors = 0,
    this.upcomingEvents = 0,
    this.totalRsvps = 0,
    this.activeJobs = 0,
    this.activeInitiatives = 0,
    this.totalRaised = 0.0,
    this.totalMentorshipRequests = 0,
  });

  factory AlumniAdminStatsModel.fromJson(Map<String, dynamic> json) {
    return AlumniAdminStatsModel(
      totalAlumni: int.tryParse(json['total_alumni']?.toString() ?? '0') ?? 0,
      verifiedAlumni: int.tryParse(json['verified_alumni']?.toString() ?? '0') ?? 0,
      activeMentors: int.tryParse(json['active_mentors']?.toString() ?? '0') ?? 0,
      upcomingEvents: int.tryParse(json['upcoming_events']?.toString() ?? '0') ?? 0,
      totalRsvps: int.tryParse(json['total_rsvps']?.toString() ?? '0') ?? 0,
      activeJobs: int.tryParse(json['active_jobs']?.toString() ?? '0') ?? 0,
      activeInitiatives: int.tryParse(json['active_initiatives']?.toString() ?? '0') ?? 0,
      totalRaised: double.tryParse(json['total_raised']?.toString() ?? '0') ?? 0.0,
      totalMentorshipRequests: int.tryParse(json['total_mentorship_requests']?.toString() ?? '0') ?? 0,
    );
  }
}
