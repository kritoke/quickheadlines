export interface TabResponse {
	name: string;
}

export interface ItemResponse {
	title: string;
	link: string;
	version?: string;
	pubDate?: number;
}

export interface FeedResponse {
	tab: string;
	url: string;
	title: string;
	siteLink: string;
	displayLink: string;
	favicon?: string;
	faviconData?: string;
	headerColor?: string;
	headerTextColor?: string;
	headerThemeColors?: { light?: { bg: string; text: string }; dark?: { bg: string; text: string } };
	items: ItemResponse[];
	totalItemCount: number;
	hasMore?: boolean;
}

export interface TimelineItemResponse {
	id: string;
	title: string;
	link: string;
	pubDate?: number;
	feedTitle: string;
	feedUrl: string;
	feedLink: string;
	favicon?: string;
	faviconData?: string;
	headerColor?: string;
	headerTextColor?: string;
	clusterId?: string;
	isRepresentative: boolean;
	clusterSize?: number;
}

export interface StoryResponse {
	id: string;
	title: string;
	link: string;
	pubDate?: number;
	feedTitle: string;
	feedUrl: string;
	feedLink: string;
	favicon?: string;
	faviconData?: string;
	headerColor?: string;
}

export interface ClusterResponse {
	id: string;
	representative: StoryResponse;
	others: StoryResponse[];
	clusterSize: number;
}

export interface FeedsPageResponse {
	tabs: TabResponse[];
	activeTab: string;
	feeds: FeedResponse[];
	isClustering: boolean;
}

export interface TimelinePageResponse {
	items: TimelineItemResponse[];
	hasMore: boolean;
	totalCount: number;
	isClustering: boolean;
}

export interface ClustersResponse {
	clusters: ClusterResponse[];
	totalCount: number;
}

export interface VersionResponse {
	isClustering: boolean;
	updatedAt: number;
}
