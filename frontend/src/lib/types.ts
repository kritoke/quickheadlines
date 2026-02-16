export interface TabResponse {
	name: string;
}

export interface ItemResponse {
	title: string;
	link: string;
	version?: string;
	pub_date?: number;
}

export interface FeedResponse {
	tab: string;
	url: string;
	title: string;
	site_link: string;
	display_link: string;
	favicon?: string;
	favicon_data?: string;
	header_color?: string;
	header_text_color?: string;
	header_theme_colors?: { light?: { bg: string; text: string }; dark?: { bg: string; text: string } };
	items: ItemResponse[];
	total_item_count: number;
	has_more?: boolean;
}

export interface TimelineItemResponse {
	id: string;
	title: string;
	link: string;
	pub_date?: number;
	feed_title: string;
	feed_url: string;
	feed_link: string;
	favicon?: string;
	favicon_data?: string;
	header_color?: string;
	header_text_color?: string;
	cluster_id?: string;
	is_representative: boolean;
	cluster_size?: number;
}

export interface StoryResponse {
	id: string;
	title: string;
	link: string;
	pub_date?: number;
	feed_title: string;
	feed_url: string;
	feed_link: string;
	favicon?: string;
	favicon_data?: string;
	header_color?: string;
}

export interface ClusterResponse {
	id: string;
	representative: StoryResponse;
	others: StoryResponse[];
	cluster_size: number;
}

export interface FeedsPageResponse {
	tabs: TabResponse[];
	active_tab: string;
	feeds: FeedResponse[];
	software_releases: FeedResponse[];
	is_clustering: boolean;
}

export interface TimelinePageResponse {
	items: TimelineItemResponse[];
	has_more: boolean;
	total_count: number;
	is_clustering: boolean;
}

export interface ClustersResponse {
	clusters: ClusterResponse[];
	total_count: number;
}

export interface ClusterItemsResponse {
	cluster_id: string;
	items: StoryResponse[];
}

export interface VersionResponse {
	is_clustering: boolean;
	updated_at: number;
}
