#if UNITY_EDITOR || EVAC_INSPECTION
using System;
using System.IO;
using System.Text;
using Unity.Collections;
using UnityEngine;

namespace Evac
{
    // Record the listener's actual game mix on the same clock as Time.captureFramerate.
    sealed class FilmAudio : IDisposable
    {
        readonly int rate,channels;
        readonly BinaryWriter wav;
        int sampleFrames;
        public bool Recording { get; }
        public float Peak { get; private set; }
        public double Seconds => (double)sampleFrames/rate;

        public FilmAudio(string path)
        {
            rate=AudioSettings.outputSampleRate;
            channels=AudioSettings.speakerMode.ChannelCount();
            if(rate<=0 || channels<=0)return;
            wav=new BinaryWriter(File.Create(path));
            wav.Write(Encoding.ASCII.GetBytes("RIFF"));
            wav.Write(0);
            wav.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
            wav.Write(16);
            wav.Write((short)1);
            wav.Write((short)channels);
            wav.Write(rate);
            wav.Write(rate*channels*2);
            wav.Write((short)(channels*2));
            wav.Write((short)16);
            wav.Write(Encoding.ASCII.GetBytes("data"));
            wav.Write(0);
            Recording=AudioRenderer.Start();
        }

        public bool WriteFrame()
        {
            int count=AudioRenderer.GetSampleCountForCaptureFrame();
            if(count<=0)return false;
            using var buffer=new NativeArray<float>(count*channels,Allocator.Temp,NativeArrayOptions.UninitializedMemory);
            if(!AudioRenderer.Render(buffer))return false;
            for(int i=0;i<buffer.Length;i++)
            {
                float value=Mathf.Clamp(buffer[i],-1,1);
                Peak=Mathf.Max(Peak,Mathf.Abs(value));
                wav.Write((short)Mathf.RoundToInt(value*32767));
            }
            sampleFrames+=count;
            return true;
        }

        public void Dispose()
        {
            if(Recording)AudioRenderer.Stop();
            if(wav==null)return;
            int bytes=sampleFrames*channels*2;
            wav.Seek(4,SeekOrigin.Begin);wav.Write(bytes+36);
            wav.Seek(40,SeekOrigin.Begin);wav.Write(bytes);
            wav.Dispose();
        }
    }
}
#endif
