/*
 * Copyright (C) 2026 The Mumba Project
 * SPDX-License-Identifier: Apache-2.0
 */

#include <array>
#include <cmath>
#include <memory>
#include <optional>
#include <vector>

#include <aidl/android/hardware/audio/effect/BnEffect.h>
#include <system/audio_effects/effect_uuid.h>

#include "effect-impl/EffectImpl.h"

namespace aidl::android::hardware::audio::effect {
namespace {

using aidl::android::media::audio::common::AudioUuid;

// Private effect type and implementation UUIDs for Mumba's speaker-only correction.
const AudioUuid kMumbaSpeakerEqType = {
        .timeLow = static_cast<int32_t>(0x8de9f101u),
        .timeMid = 0x4f4b,
        .timeHiAndVersion = 0xa112,
        .clockSeq = 0x81a4,
        .node = {0x6d, 0x75, 0x6d, 0x62, 0x61, 0x01},
};
const AudioUuid kMumbaSpeakerEqImpl = {
        .timeLow = static_cast<int32_t>(0x8de9f102u),
        .timeMid = 0x4f4b,
        .timeHiAndVersion = 0xa112,
        .clockSeq = 0x81a4,
        .node = {0x6d, 0x75, 0x6d, 0x62, 0x61, 0x02},
};

constexpr int32_t kDefaultSampleRate = 48000;
constexpr double kPi = 3.14159265358979323846;

struct BiquadState {
    float z1 = 0.0f;
    float z2 = 0.0f;
};

struct PeakingFilter {
    double b0 = 1.0;
    double b1 = 0.0;
    double b2 = 0.0;
    double a1 = 0.0;
    double a2 = 0.0;
    std::vector<BiquadState> state;

    void configure(double sampleRate, double frequency, double gainDb, double q,
                   size_t channels) {
        const double a = std::pow(10.0, gainDb / 40.0);
        const double omega = 2.0 * kPi * frequency / sampleRate;
        const double cosOmega = std::cos(omega);
        const double alpha = std::sin(omega) / (2.0 * q);
        const double a0 = 1.0 + alpha / a;

        b0 = (1.0 + alpha * a) / a0;
        b1 = (-2.0 * cosOmega) / a0;
        b2 = (1.0 - alpha * a) / a0;
        a1 = (-2.0 * cosOmega) / a0;
        a2 = (1.0 - alpha / a) / a0;
        state.assign(channels, {});
    }

    float process(float input, size_t channel) {
        auto& s = state[channel];
        const float output = static_cast<float>(b0) * input + s.z1;
        s.z1 = static_cast<float>(b1) * input - static_cast<float>(a1) * output + s.z2;
        s.z2 = static_cast<float>(b2) * input - static_cast<float>(a2) * output;
        return output;
    }
};

class MumbaSpeakerEqContext final : public EffectContext {
  public:
    explicit MumbaSpeakerEqContext(const Parameter::Common& common)
        : EffectContext(1 /* statusFmqDepth */, common),
          mChannels(common::getChannelCount(common.output.base.channelMask)) {
        const int32_t requestedRate = common.output.base.sampleRate;
        const double sampleRate = requestedRate > 0 ? requestedRate : kDefaultSampleRate;
        // Cut-only fit to the Notebookcheck maximum-volume curve, aiming for
        // ~65 dB(A) from 500 Hz to 12.5 kHz. 1/3-octave-Q notches address the
        // measured peaks; the weak 100-400 Hz response receives no boost.
        constexpr std::array<double, 10> kCentersHz = {
                630.0, 1000.0, 1250.0, 1600.0, 2000.0,
                2500.0, 5000.0, 6300.0, 8000.0, 12500.0};
        constexpr std::array<double, 10> kGainsDb = {
                -2.9, -9.7, -6.6, -6.4, -4.6, -1.9, -2.9, -6.9, -5.5, -1.0};
        constexpr std::array<double, 10> kQ = {4.3, 4.3, 4.3, 4.3, 4.3,
                                                4.3, 4.3, 4.3, 4.3, 4.3};
        for (size_t i = 0; i < mFilters.size(); ++i) {
            mFilters[i].configure(sampleRate, kCentersHz[i], kGainsDb[i], kQ[i], mChannels);
        }
    }

    IEffect::Status process(float* input, float* output, int samples) {
        if (mChannels == 0 || samples < 0 || samples % mChannels != 0) {
            return {EX_ILLEGAL_ARGUMENT, 0, 0};
        }
        for (int i = 0; i < samples; ++i) {
            const size_t channel = static_cast<size_t>(i) % mChannels;
            float value = input[i];
            for (auto& filter : mFilters) {
                value = filter.process(value, channel);
            }
            output[i] = value;
        }
        return {STATUS_OK, samples, samples};
    }

  private:
    size_t mChannels;
    std::array<PeakingFilter, 10> mFilters;
};

class MumbaSpeakerEqualizer final : public EffectImpl {
  public:
    static const Descriptor kDescriptor;

    ndk::ScopedAStatus getDescriptor(Descriptor* result) override {
        *result = kDescriptor;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus setParameterSpecific(const Parameter::Specific& /*specific*/)
            REQUIRES(mImplMutex) override {
        return ndk::ScopedAStatus::fromExceptionCode(EX_ILLEGAL_ARGUMENT);
    }

    ndk::ScopedAStatus getParameterSpecific(const Parameter::Id& /*id*/,
                                             Parameter::Specific* /*specific*/)
            REQUIRES(mImplMutex) override {
        return ndk::ScopedAStatus::fromExceptionCode(EX_ILLEGAL_ARGUMENT);
    }

    std::shared_ptr<EffectContext> createContext(const Parameter::Common& common)
            REQUIRES(mImplMutex) override {
        mContext = std::make_shared<MumbaSpeakerEqContext>(common);
        return mContext;
    }

    RetCode releaseContext() REQUIRES(mImplMutex) override {
        mContext.reset();
        return RetCode::SUCCESS;
    }

    std::string getEffectName() override { return "MumbaSpeakerEqualizer"; }

    IEffect::Status effectProcessImpl(float* input, float* output, int samples)
            REQUIRES(mImplMutex) override {
        return mContext ? mContext->process(input, output, samples)
                        : IEffect::Status{EX_NULL_POINTER, 0, 0};
    }

  private:
    std::shared_ptr<MumbaSpeakerEqContext> mContext GUARDED_BY(mImplMutex);
};

const Descriptor MumbaSpeakerEqualizer::kDescriptor = {
        .common = {.id = {.type = kMumbaSpeakerEqType,
                          .uuid = kMumbaSpeakerEqImpl,
                          .proxy = std::nullopt},
                   .flags = {.type = Flags::Type::POST_PROC,
                             .insert = Flags::Insert::LAST,
                             .volume = Flags::Volume::NONE},
                   .name = "MumbaSpeakerEqualizer",
                   .implementor = "Mumba"}};

}  // namespace
}  // namespace aidl::android::hardware::audio::effect

extern "C" binder_exception_t createEffect(
        const aidl::android::media::audio::common::AudioUuid* implementationUuid,
        std::shared_ptr<aidl::android::hardware::audio::effect::IEffect>* instance) {
    using namespace aidl::android::hardware::audio::effect;
    if (!implementationUuid || *implementationUuid != kMumbaSpeakerEqImpl || !instance) {
        return EX_ILLEGAL_ARGUMENT;
    }
    *instance = ndk::SharedRefBase::make<MumbaSpeakerEqualizer>();
    return EX_NONE;
}

extern "C" binder_exception_t queryEffect(
        const aidl::android::media::audio::common::AudioUuid* implementationUuid,
        aidl::android::hardware::audio::effect::Descriptor* descriptor) {
    using namespace aidl::android::hardware::audio::effect;
    if (!implementationUuid || *implementationUuid != kMumbaSpeakerEqImpl || !descriptor) {
        return EX_ILLEGAL_ARGUMENT;
    }
    *descriptor = MumbaSpeakerEqualizer::kDescriptor;
    return EX_NONE;
}
