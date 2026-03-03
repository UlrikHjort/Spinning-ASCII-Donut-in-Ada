-- ***************************************************************************
--  Spinning ASCII Donut in Ada - rendered with luminance shading and ANSI colors.
--
--                   Copyright (C) 2026 By Ulrik Hørlyk Hjort
--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
-- LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
-- OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
-- WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-- ***************************************************************************           
with Ada.Text_IO;
with Ada.Numerics;
with Ada.Numerics.Elementary_Functions;

procedure Donut is
   use Ada.Text_IO;
   use Ada.Numerics.Elementary_Functions;

   Width  : constant := 80;
   Height : constant := 22;

   subtype Col_T is Integer range 0 .. Width  - 1;
   subtype Row_T is Integer range 0 .. Height - 1;

   Output : array (Row_T, Col_T) of Character;
   ZBuf   : array (Row_T, Col_T) of Float;
   LumBuf : array (Row_T, Col_T) of Integer;

   --  Luminance palette: darkest -> brightest
   Chars : constant String := ".,-~:;=!*#$@";

   ESC : constant Character := ASCII.ESC;

   --  ANSI color gradient: dim-blue -> cyan -> green -> yellow -> bright-white
   procedure Set_Color (L : Integer) is
   begin
      case L is
         when 1      => Put (ESC & "[2;34m");   --  dim blue
         when 2      => Put (ESC & "[34m");      --  blue
         when 3      => Put (ESC & "[36m");      --  cyan
         when 4      => Put (ESC & "[1;36m");    --  bright cyan
         when 5      => Put (ESC & "[32m");      --  green
         when 6      => Put (ESC & "[1;32m");    --  bright green
         when 7      => Put (ESC & "[33m");      --  yellow
         when 8      => Put (ESC & "[1;33m");    --  bright yellow
         when 9      => Put (ESC & "[31m");      --  red
         when 10     => Put (ESC & "[1;31m");    --  bright red
         when 11     => Put (ESC & "[37m");      --  white
         when 12     => Put (ESC & "[1;37m");    --  bright white
         when others => Put (ESC & "[0m");
      end case;
   end Set_Color;

   --  Torus geometry constants
   R1 : constant Float := 1.0;   --  tube radius
   R2 : constant Float := 2.0;   --  distance from tube center to torus center
   K2 : constant Float := 5.0;   --  viewer distance
   K1 : constant Float :=
     Float (Width) * K2 * 3.0 / (8.0 * (R1 + R2));  --  projection scale

   Pi : constant Float := Ada.Numerics.Pi;

   A : Float := 0.0;   --  rotation around X
   B : Float := 0.0;   --  rotation around Z

begin
   Put (ESC & "[?25l");   --  hide cursor
   Put (ESC & "[2J");     --  clear screen

   loop
      --  Clear frame buffers
      for R in Row_T loop
         for C in Col_T loop
            Output (R, C) := ' ';
            ZBuf   (R, C) := 0.0;
            LumBuf (R, C) := 0;
         end loop;
      end loop;

      --  Render torus
      declare
         CosA : constant Float := Cos (A);
         SinA : constant Float := Sin (A);
         CosB : constant Float := Cos (B);
         SinB : constant Float := Sin (B);
         Th   : Float := 0.0;
      begin
         while Th < 2.0 * Pi loop
            declare
               CosTh : constant Float := Cos (Th);
               SinTh : constant Float := Sin (Th);
               Ph    : Float := 0.0;
            begin
               while Ph < 2.0 * Pi loop
                  declare
                     CosPh : constant Float := Cos (Ph);
                     SinPh : constant Float := Sin (Ph);

                     --  Point on the circle in the XZ plane before spin
                     Cx : constant Float := R2 + R1 * CosTh;
                     Cy : constant Float := R1 * SinTh;

                     --  3-D position after rotation A (X-axis) then B (Z-axis)
                     X : constant Float :=
                       Cx * (CosB * CosPh + SinA * SinB * SinPh)
                       - Cy * CosA * SinB;
                     Y : constant Float :=
                       Cx * (SinB * CosPh - SinA * CosB * SinPh)
                       + Cy * CosA * CosB;
                     Z : constant Float :=
                       K2 + CosA * Cx * SinPh + Cy * SinA;

                     OOZ : constant Float := 1.0 / Z;  --  1/z for z-buffer & projection

                     --  Screen-space projection (Y scaled for square pixels)
                     XP : constant Integer :=
                       Integer (Float (Width)  / 2.0 + K1 * OOZ * X);
                     YP : constant Integer :=
                       Integer (Float (Height) / 2.0 - K1 * OOZ * Y * 0.45);

                     --  Luminance: dot product of surface normal with light dir
                     L  : constant Float :=
                       CosPh * CosTh * SinB
                       - CosA * CosTh * SinPh
                       - SinA * SinTh
                       + CosB * (CosA * SinTh - CosTh * SinPh * SinA);

                     LI : Integer;
                  begin
                     if XP in Col_T and then YP in Row_T then
                        if L > 0.0 and then OOZ > ZBuf (YP, XP) then
                           ZBuf (YP, XP) := OOZ;
                           LI := Integer (L * 8.0);
                           if LI < 1  then LI := 1;  end if;
                           if LI > 12 then LI := 12; end if;
                           Output (YP, XP) := Chars (LI);
                           LumBuf (YP, XP) := LI;
                        end if;
                     end if;
                  end;
                  Ph := Ph + 0.02;
               end loop;
            end;
            Th := Th + 0.07;
         end loop;
      end;

      --  Draw frame
      Put (ESC & "[1;1H");   --  cursor to row 1 col 1
      for R in Row_T loop
         declare
            Prev_L : Integer := -1;
         begin
            for C in Col_T loop
               declare
                  Ch : constant Character := Output (R, C);
                  LV : constant Integer   := LumBuf (R, C);
               begin
                  if Ch /= ' ' then
                     if LV /= Prev_L then
                        Set_Color (LV);
                        Prev_L := LV;
                     end if;
                  elsif Prev_L /= 0 then
                     Put (ESC & "[0m");
                     Prev_L := 0;
                  end if;
                  Put (Ch);
               end;
            end loop;
         end;
         Put (ESC & "[0m");
         New_Line;
      end loop;

      --  Advance rotation angles
      A := A + 0.07;
      B := B + 0.03;

      delay 0.030;
   end loop;

exception
   when others =>
      --  Restore terminal on exit (Ctrl+C or any error)
      Put (ESC & "[?25h");
      Put (ESC & "[0m");
      New_Line;
end Donut;
