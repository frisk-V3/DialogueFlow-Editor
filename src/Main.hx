import js.Browser.*;
import js.html.*;

// ===== データ型 (Haxeではクラスの外で定義します) =====
typedef Condition = {
    flag:String,
    required:Bool
}

typedef Choice = {
    text:String,
    next:String,
    conditions:Array<Condition>
}

typedef DialogueNode = {
    id:String,
    text:String,
    choices:Array<Choice>,
    flags:Array<String>
}

class Main {
    // ===== エディタ本体 =====
    static var nodes:Array<DialogueNode> = [];

    static function main() {
        // UI イベント登録
        document.getElementById("addNode").onclick = function(_) addNode();
        document.getElementById("exportJson").onclick = function(_) {
            document.getElementById("output").textContent = exportJSON();
        }
        document.getElementById("exportXml").onclick = function(_) {
            document.getElementById("output").textContent = exportXML();
        }

        render();
    }

    // ===== ノード追加 =====
    static function addNode() {
        var id = "node_" + nodes.length;
        nodes.push({
            id: id,
            text: "",
            choices: [],
            flags: []
        });
        render();
    }

    // ===== 選択肢追加 =====
    static function addChoice(nodeIndex:Int) {
        var node = nodes[nodeIndex];

        var text = window.prompt("選択肢テキスト:", "");
        if (text == null || text == "") return;

        var next = window.prompt("遷移先ノードID:", "");
        if (next == null) next = "";

        var condStr = window.prompt("条件フラグ（例: hasKey,!metNPC）:", "");
        var conditions:Array<Condition> = [];

        if (condStr != null && condStr != "") {
            for (p in condStr.split(",")) {
                var s = StringTools.trim(p);
                if (s == "") continue;

                var required = true;
                var flag = s;

                if (StringTools.startsWith(s, "!")) {
                    required = false;
                    flag = s.substr(1);
                }

                conditions.push({ flag: flag, required: required });
            }
        }

        node.choices.push({
            text: text,
            next: next,
            conditions: conditions
        });

        render();
    }

    // ===== ノードテキスト更新 =====
    static function updateNodeText(i:Int, value:String) {
        nodes[i].text = value;
    }

    // ===== フラグ更新 =====
    static function updateNodeFlags(i:Int, value:String) {
        var flags = [];
        for (p in value.split(",")) {
            var s = StringTools.trim(p);
            if (s != "") flags.push(s);
        }
        nodes[i].flags = flags;
    }

    // ===== UI 再描画 =====
    static function render() {
        var container = document.getElementById("editor");
        container.innerHTML = "";

        for (i in 0...nodes.length) {
            var node = nodes[i];

            var box = document.createDivElement();
            box.style.border = "1px solid #ccc";
            box.style.padding = "8px";
            box.style.marginBottom = "8px";

            var title = document.createElement("h2");
            title.textContent = node.id;
            box.appendChild(title);

            // テキスト
            var textLabel = document.createElement("div");
            textLabel.textContent = "テキスト:";
            box.appendChild(textLabel);

            var textarea = document.createTextAreaElement();
            textarea.value = node.text;
            textarea.rows = 3;
            textarea.style.width = "100%";
            textarea.oninput = function(_) updateNodeText(i, textarea.value);
            box.appendChild(textarea);

            // フラグ
            var flagLabel = document.createElement("div");
            flagLabel.textContent = "到達時に立てるフラグ（カンマ区切り）:";
            flagLabel.style.marginTop = "6px";
            box.appendChild(flagLabel);

            var flagInput = document.createInputElement();
            flagInput.type = "text";
            flagInput.style.width = "100%";
            flagInput.value = node.flags.join(", ");
            flagInput.oninput = function(_) updateNodeFlags(i, flagInput.value);
            box.appendChild(flagInput);

            // 選択肢一覧
            var choiceTitle = document.createElement("div");
            choiceTitle.textContent = "選択肢:";
            choiceTitle.style.marginTop = "8px";
            box.appendChild(choiceTitle);

            for (c in node.choices) {
                var cDiv = document.createDivElement();
                cDiv.style.borderTop = "1px dashed #aaa";
                cDiv.style.marginTop = "4px";
                cDiv.style.paddingTop = "4px";

                var cText = '"' + c.text + '" → ' + (c.next == "" ? "(終端)" : c.next);

                if (c.conditions.length > 0) {
                    var condStr = [];
                    for (cond in c.conditions) {
                        condStr.push((cond.required ? "" : "!") + cond.flag);
                    }
                    cText += " [条件: " + condStr.join(", ") + "]";
                }

                cDiv.textContent = cText;
                box.appendChild(cDiv);
            }

            var addChoiceBtn = document.createButtonElement();
            addChoiceBtn.textContent = "選択肢追加";
            addChoiceBtn.onclick = function(_) addChoice(i);
            box.appendChild(addChoiceBtn);

            container.appendChild(box);
        }
    }

    // ===== JSON 出力 =====
    static function exportJSON():String {
        return haxe.Json.stringify(nodes, "\t");
    }

    // ===== XML 出力 =====
    static function exportXML():String {
        var b = new StringBuf();
        b.add("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
        b.add("<dialogues>\n");

        for (node in nodes) {
            b.add('  <node id="${node.id}">\n');
            b.add('    <text>${escapeXml(node.text)}</text>\n');

            if (node.flags.length > 0) {
                b.add('    <flags>\n');
                for (f in node.flags) {
                    b.add('      <flag>${escapeXml(f)}</flag>\n');
                }
                b.add('    </flags>\n');
            }

            if (node.choices.length > 0) {
                b.add('    <choices>\n');
                for (c in node.choices) {
                    b.add('      <choice next="${escapeXmlAttr(c.next)}">\n');
                    b.add('        <text>${escapeXml(c.text)}</text>\n');

                    if (c.conditions.length > 0) {
                        b.add('        <conditions>\n');
                        for (cond in c.conditions) {
                            b.add('          <condition flag="${escapeXmlAttr(cond.flag)}" required="${cond.required}" />\n');
                        }
                        b.add('        </conditions>\n');
                    }

                    b.add('      </choice>\n');
                }
                b.add('    </choices>\n');
            }

            b.add("  </node>\n");
        }

        b.add("</dialogues>\n");
        return b.toString();
    }

    // ===== XML エスケープ =====
    static function escapeXml(s:String):String {
        return s
            .split("&").join("&amp;")
            .split("<").join("&lt;")
            .split(">").join("&gt;");
    }

    static function escapeXmlAttr(s:String):String {
        return escapeXml(s).split("\"").join("&quot;");
    }
}
