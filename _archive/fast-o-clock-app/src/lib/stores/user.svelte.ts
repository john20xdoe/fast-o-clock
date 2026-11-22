type Link = {
	title: string;
	url: string;
};

export type User = {
	id: string;
	firstName: string;
	lastName: string;
	about: string;
	email?: string;
	links: Link[];
};

// TODO: add userState
