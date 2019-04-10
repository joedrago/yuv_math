clamp = (v, min, max) ->
  return Math.min(Math.max(v, min), max)

pad = (str, len, ch) ->
  str = String(str)
  i = -1
  if !ch and (ch != 0)
    ch = ' '
  len = len - str.length
  while ++i < len
    str = ch + str
  return str

line = (len) ->
  str = ""
  for i in [0...len]
    str += "-"
  return str

yuvRoundtrip = (opts) ->
  # opt parsing and basic values
  step = opts.step or 1
  maxChannel = (1 << opts.bpc) - 1
  maxChannelsDelta = 0
  maxSingleChannelDelta = 0
  countTested = 0
  countFlawed = 0

  console.log ""
  console.log opts.title
  console.log "#{line(opts.title.length)}"

  # prefixes:
  #   s - source
  #   d - destination
  #   u - unorm
  #   f - float

  for suR in [0..maxChannel] by step
    sfR = suR / maxChannel
    for suG in [0..maxChannel] by step
      sfG = suG / maxChannel
      for suB in [0..maxChannel] by step
        sfB = suB / maxChannel

        countTested += 1

        # RGB -> YUV conversion
        sfY = (opts.kr * sfR) + (opts.kg * sfG) + (opts.kb * sfB)
        sfU = (sfB - sfY) / (2 * (1 - opts.kb))
        sfV = (sfR - sfY) / (2 * (1 - opts.kr))

        # Quantize YUV into opts.bpc bits
        uY = Math.round(clamp(sfY, 0, 1) * maxChannel)
        uU = Math.round(clamp(sfU + 0.5, 0, 1) * maxChannel)
        uV = Math.round(clamp(sfV + 0.5, 0, 1) * maxChannel)

        # unorm YUV -> float YUV
        dfY =  uY / maxChannel
        dfU = (uU / maxChannel) - 0.5
        dfV = (uV / maxChannel) - 0.5

        # YUV -> RGB conversion
        dfR = dfY + (2 * (1 - opts.kr)) * dfV
        dfB = dfY + (2 * (1 - opts.kb)) * dfU
        dfG = dfY - (2 * ((opts.kr * (1 - opts.kr) * dfV) + (opts.kb * (1 - opts.kb) * dfU))) / opts.kg

        # Quantize dest RGB into opts.bpc bits
        duR = Math.round(clamp(dfR, 0, 1) * maxChannel)
        duG = Math.round(clamp(dfG, 0, 1) * maxChannel)
        duB = Math.round(clamp(dfB, 0, 1) * maxChannel)

        if (suR != duR) or (suG != duG) or (suB != duB)
          deltaR = Math.abs(suR - duR)
          deltaG = Math.abs(suG - duG)
          deltaB = Math.abs(suB - duB)
          channelsDelta = deltaR + deltaG + deltaB
          singleChannelDelta = Math.max(deltaR, Math.max(deltaG, deltaB))

          # global stats
          countFlawed += 1
          maxChannelsDelta = Math.max(maxChannelsDelta, channelsDelta)
          maxSingleChannelDelta = Math.max(maxSingleChannelDelta, singleChannelDelta)

          if opts.verbose
            console.log "(#{pad(suR, 3)}, #{pad(suG, 3)}, #{pad(suB, 3)}) -> (#{pad(duR, 3)}, #{pad(duG, 3)}, #{pad(duB, 3)}) - delta: #{channelsDelta} single:#{singleChannelDelta}"

  console.log "Error Rate               : #{countFlawed} / #{countTested} (#{(100.0 * countFlawed / countTested).toFixed(2)}%)"
  console.log "Max single channel delta : #{maxSingleChannelDelta}"
  console.log "Max delta sum (all chans): #{maxChannelsDelta}"

main = ->
  verbose = false

  SRGB_KR = 0.2126
  SRGB_KB = 0.0722
  SRGB_KG = 1.0 - SRGB_KR - SRGB_KB

  yuvRoundtrip {
    verbose: verbose
    title: "sRGB 8Bit"
    bpc: 8
    step: 1
    kr: SRGB_KR
    kg: SRGB_KG
    kb: SRGB_KB
  }

  yuvRoundtrip {
    verbose: verbose
    title: "sRGB 10Bit"
    bpc: 10
    step: 1
    kr: SRGB_KR
    kg: SRGB_KG
    kb: SRGB_KB
  }

main()
