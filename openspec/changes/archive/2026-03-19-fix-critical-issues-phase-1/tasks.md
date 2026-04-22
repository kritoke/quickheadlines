## 1. Security Config Consolidation

- [x] 1.1 Remove duplicate SecurityConfig definition at config.cr lines 91-99
- [x] 1.2 Verify single SecurityConfig struct compiles correctly
- [x] 1.3 Test YAML config parsing with security settings

## 2. Rate Limiter Memory Safety

- [x] 2.1 Add CLEANUP_INTERVAL constant to rate_limiter.cr
- [x] 2.2 Add @last_cleanup instance variable
- [x] 2.3 Implement cleanup_if_needed private method
- [x] 2.4 Call cleanup_if_needed from allow? method
- [ ] 2.5 Test rate limiter with many unique IPs
- [ ] 2.6 Verify memory doesn't grow unbounded

## 3. Proxy URL Validation

- [x] 3.1 Add validate_redirect_url private method to api_controller.cr
- [x] 3.2 Block private IP ranges in redirects (127.x, 192.168.x, 10.x, 172.16.x, 169.254.x, localhost)
- [x] 3.3 Block non-HTTP schemes in redirects
- [ ] 3.4 Test proxy with redirects to allowed domains
- [ ] 3.5 Test proxy blocks redirects to private networks

## 4. Trusted Proxy Validation

- [x] 4.1 Add TRUSTED_PROXIES constant to quickheadlines.cr
- [x] 4.2 Create extract_client_ip helper method
- [x] 4.3 Update WebSocket handler to use extract_client_ip
- [x] 4.4 Update check_rate_limit to use trusted proxy logic
- [ ] 4.5 Test WebSocket connection from trusted proxy
- [ ] 4.6 Test WebSocket connection from untrusted IP

## 5. Testing & Verification

- [x] 5.1 Run crystal build to verify compilation
- [x] 5.2 Run crystal spec to verify tests pass
- [ ] 5.3 Test application startup with feeds.yml
- [ ] 5.4 Verify security settings load correctly
- [ ] 5.5 Test rate limiting behavior
- [ ] 5.6 Test image proxy with various URLs

## 6. Cleanup & Documentation

- [x] 6.1 Run ameba --fix to auto-format code
- [ ] 6.2 Add comments explaining security decisions
- [ ] 6.3 Update deployment documentation if needed
