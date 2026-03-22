import { goto } from '$app/navigation';

/**
 * Centralized navigation service for consistent view switching and URL management.
 * This service ensures all navigation operations use the same logic and maintain
 * proper tab persistence across views.
 */
export class NavigationService {
  /**
   * Get the current tab from URL parameters.
   * @returns The current tab name, or 'all' if not specified
   */
  static getCurrentTab(): string {
    if (typeof window === 'undefined') {
      return 'all';
    }
    const params = new URLSearchParams(window.location.search);
    return params.get('tab') || 'all';
  }

  /**
   * Navigate to the timeline view for the specified tab.
   * @param tab The tab to navigate to (defaults to current tab)
   */
  static async navigateToTimeline(tab: string = this.getCurrentTab()): Promise<void> {
    const encodedTab = encodeURIComponent(tab);
    const url = tab === 'all' ? '/timeline' : `/timeline?tab=${encodedTab}`;
    await goto(url, { replaceState: true, noScroll: false });
  }

  /**
   * Navigate to the feed view for the specified tab.
   * @param tab The tab to navigate to (defaults to current tab)  
   */
  static async navigateToFeeds(tab: string = this.getCurrentTab()): Promise<void> {
    const encodedTab = encodeURIComponent(tab);
    const url = tab === 'all' ? '/' : `/?tab=${encodedTab}`;
    await goto(url, { replaceState: true, noScroll: false });
  }

  /**
   * Navigate to the global timeline (all tabs).
   */
  static async navigateToGlobalTimeline(): Promise<void> {
    await goto('/timeline', { replaceState: true, noScroll: false });
  }

  /**
   * Navigate to the global feed view (all tabs).
   */
  static async navigateToGlobalFeeds(): Promise<void> {
    await goto('/', { replaceState: true, noScroll: false });
  }

  /**
   * Toggle between feed and timeline views while preserving the current tab.
   */
  static async toggleView(): Promise<void> {
    const currentTab = this.getCurrentTab();
    const isOnTimeline = typeof window !== 'undefined' && window.location.pathname.startsWith('/timeline');
    
    if (isOnTimeline) {
      await this.navigateToFeeds(currentTab);
    } else {
      await this.navigateToTimeline(currentTab);
    }
  }
}