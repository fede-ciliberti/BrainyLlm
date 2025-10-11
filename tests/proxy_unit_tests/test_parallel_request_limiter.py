import asyncio
import os
import sys
from unittest.mock import Mock, patch, AsyncMock
import pytest
from fastapi import HTTPException

sys.path.insert(0, os.path.abspath("../.."))
import litellm
from litellm.proxy.hooks.parallel_request_limiter import ParallelRequestLimiter
from litellm.proxy.utils import InternalUsageCache
from litellm.proxy._types import UserAPIKeyAuth


@pytest.fixture
def parallel_request_limiter():
    # Mock the InternalUsageCache
    mock_internal_usage_cache = AsyncMock(spec=InternalUsageCache)
    limiter = ParallelRequestLimiter(internal_usage_cache=mock_internal_usage_cache)
    limiter.print_verbose = lambda msg: print(msg)
    # Attach the mock to the limiter instance so it can be accessed in tests
    limiter.internal_usage_cache = mock_internal_usage_cache
    return limiter


@pytest.mark.asyncio
async def test_parallel_request_limiter_exceeds_limit(parallel_request_limiter):
    """
    Test that the parallel request limiter raises a HTTPException when the limit is exceeded.
    """
    user_api_key_dict = UserAPIKeyAuth(
        api_key="test_key", max_parallel_requests=1, rpm_limit=10, tpm_limit=1000
    )

    # Simulate that the new request exceeds the limit
    parallel_request_limiter.internal_usage_cache.async_increment_cache.return_value = 2

    with pytest.raises(HTTPException) as excinfo:
        await parallel_request_limiter.async_pre_call_hook(
            user_api_key_dict=user_api_key_dict,
            cache=Mock(),
            data={"model": "gpt-4"},
            call_type="completion",
        )
    assert excinfo.value.status_code == 429


@pytest.mark.asyncio
async def test_parallel_request_limiter_within_limit(parallel_request_limiter):
    """
    Test that the parallel request limiter does not raise an exception when within the limit.
    """
    user_api_key_dict = UserAPIKeyAuth(
        api_key="test_key", max_parallel_requests=2, rpm_limit=10, tpm_limit=1000
    )

    # Simulate that the new request is within the limit
    parallel_request_limiter.internal_usage_cache.async_increment_cache.return_value = 2

    # This should not raise an exception
    await parallel_request_limiter.async_pre_call_hook(
        user_api_key_dict=user_api_key_dict,
        cache=Mock(),
        data={"model": "gpt-4"},
        call_type="completion",
    )
    # Verify that the cache increment function was called
    parallel_request_limiter.internal_usage_cache.async_increment_cache.assert_called_once()