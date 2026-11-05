#!/usr/bin/env python3
"""Build this source edition from the included prepared assets. No ROM extraction."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,tempfile
from tools.native_package import allocation_sizes,write_icon,write_lha

ROOT=Path(__file__).resolve().parent;AMIGA=ROOT/'amiga'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--rom',default=os.environ.get('AMIGA_KICKSTART',''));a=p.parse_args()
    edition=json.loads((ROOT/'source_edition.json').read_text())['edition'];demo=edition=='demo'
    release=AMIGA/'releases'/edition;release.mkdir(parents=True,exist_ok=True)
    native=AMIGA/'releases/whdload'/edition;native.mkdir(parents=True,exist_ok=True)
    profiles={};natives={}
    for profile in ['reduced','full']:
        full=profile=='full';multiplier=64 if full else 4;stem=f'bionic_commando_{edition}_{profile}_colour'
        exe=release/stem;listing=release/f'bionic_preview_{profile}.lst'
        subprocess.run(['vasmm68k_mot','-nosym','-Fhunkexe','-kick1hunks',f'-DBUILD_GFX_PROFILE={int(full)}','-L',str(listing),'-o',str(exe),'bionic_preview.asm'],cwd=AMIGA,check=True)
        hd=release/f'hd_{profile}';(hd/'s').mkdir(parents=True,exist_ok=True);(hd/'data').mkdir(exist_ok=True)
        shutil.copy2(exe,hd/'bionic_preview');shutil.copy2(AMIGA/'data'/f'c64_{edition}.bcm',hd/'data/c64_music.bcm')
        (hd/'s/startup-sequence').write_text('bionic_preview\n')
        config=release/f'{stem}.uae'
        config.write_text(f'''config_description=Bionic Commando {edition} A1200 {profile} {multiplier}x
config_version=5.0.0
use_gui=no
kickstart_rom_file={a.rom}
cpu_model=68020
cpu_speed=real
cpu_multiplier={multiplier}
cpu_compatible=true
cpu_24bit_addressing=true
cachesize=0
cpu_cycle_exact=false
cpu_memory_cycle_exact=true
blitter_cycle_exact=false
immediate_blits={'true'if full else'false'}
chipset=aga
chipset_compatible=A1200
ntsc=false
chipmem_size=4
fastmem_size=8
bogomem_size=0
nr_floppies=0
filesystem2=rw,DH0:BionicHD:{hd},0
sound_output=exact
sound_channels=stereo
sound_frequency=44100
joyport0=mouse
joyport1=joy0
joyport1mode=cd32joy
gfx_width_windowed=960
gfx_height_windowed=720
''')
        item=dict(graphics_profile=profile,graphics_build_profile=int(full),executable=exe.name,executable_sha256=digest(exe),executable_bytes=exe.stat().st_size,listing=listing.name,listing_sha256=digest(listing),hd=hd.name,configuration=config.name,cpu_multiplier=multiplier,immediate_blits=full)
        if shutil.which('xdftool'):
            disk=release/(stem+'.adf');disk.unlink(missing_ok=True)
            subprocess.run(['xdftool',str(disk),'create','+','format','Bionic'+edition.title()+profile.title(),'ffs','+','boot','install','+','makedir','s','+','write',str(hd/'s/startup-sequence'),'s/startup-sequence','+','write',str(exe),'bionic_preview'],check=True)
            item.update(disk=disk.name,disk_sha256=digest(disk),disk_bytes=disk.stat().st_size)
        profiles[profile]=item
        name=('BionicCommandoDemo'if demo else'BionicCommandoFull')+('FullColour'if full else'')
        package=native/name;(package/'data').mkdir(parents=True,exist_ok=True)
        game=package/'data/bionic_game';lst=native/f'bionic_game_{profile}.lst'
        subprocess.run(['vasmm68k_mot','-nosym','-Fhunkexe','-kick1hunks','-DBUILD_WHDLOAD=1',f'-DBUILD_GFX_PROFILE={int(full)}','-L',str(lst),'-o',str(game),'bionic_preview.asm'],cwd=AMIGA,check=True)
        memory=allocation_sizes(game);fast=0x400000 if demo else 0x700000
        assert memory['chip_hunk_bytes']+0x10000<=0x200000
        assert memory['fast_hunk_bytes']+0x10000<=fast
        slave=package/(name+'.slave')
        with tempfile.TemporaryDirectory()as t:
            d=Path(t);(d/'whd_generated.i').write_text(f'GAME_FILE_BYTES EQU {game.stat().st_size}\n')
            subprocess.run(['vasmm68k_mot','-quiet','-pic','-nosym','-Fhunkexe',f'-DBUILD_GFX_PROFILE={int(full)}','-I'+str(d),'-o',str(slave),'whdload/BionicCommandoHD.asm'],cwd=AMIGA,check=True)
        shutil.copy2(AMIGA/'data'/f'c64_{edition}.bcm',package/'data/c64_music.bcm')
        write_icon(package/(slave.name+'.info'),slave.name)
        (package/'Start').write_text(f'WHDLoad SLAVE={slave.name} PRELOAD PAL\n')
        archive=native/(name+'.lha');write_lha(package,archive)
        natives[profile]=dict(package=name,game_sha256=digest(game),slave_sha256=digest(slave),archive=archive.name,archive_sha256=digest(archive),**memory)
    (release/'edition.json').write_text(json.dumps(dict(edition=edition,playable_levels=1 if demo else 5,profiles=profiles),indent=2)+'\n')
    (native/'manifest.json').write_text(json.dumps(dict(edition=edition,profiles=natives),indent=2)+'\n')
    print('Built',edition,'reduced/full colour, HD, optional ADF and native WHDLoad packages.')

if __name__=='__main__':main()
