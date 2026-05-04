import { describe, it, expect, vi, beforeEach } from 'vitest';
import api from '../services/api';

vi.mock('axios', () => {
    const instance = {
        get: vi.fn(),
        post: vi.fn(),
        patch: vi.fn(),
        interceptors: {
            request: { use: vi.fn() },
            response: { use: vi.fn() }
        },
        defaults: { headers: { common: {} } }
    };
    return {
        default: {
            create: vi.fn(() => instance)
        }
    };
});

describe('API Service', () => {
    it('should export an axios instance', () => {
        expect(api).toBeDefined();
    });
});
